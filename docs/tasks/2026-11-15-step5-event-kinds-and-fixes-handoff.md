# Step 5 hand-off: event kinds, the open fixes, refunds in the admin panel

For `code-writer`. The task and every decision: `docs/tasks/2026-11-15-buyer-api-and-merchant-cancel.md`
(see "Event kinds" in the decisions table). Steps 1–4 are done and reviewed; a full run of the three
apps against the server worked. This round is done in three parts, **A, B, C, one at a time**, each by its
own agent run. Read the README of each project you touch first and keep its patterns.

## The decision

A merchant picks what kind of event it is when creating it: **Marathon**, **Concert** or **Show**.

- Marathon: after Select tickets the user app asks the runner details it already has (name, phone, email,
  gender, age, nationality, emergency contact, race-kit T-shirt size), one runner and one ticket per booking.
- Concert and Show: straight to checkout, nothing extra (as in the user app prototype
  `user-app/Pin User App.html`, where only the half marathon has `hasSize` and goes to "Runner details").
- The kind replaces the hidden `needsRunnerDetails` flag: a marathon needs runner details, nothing else does.
- Buyers see the kind: label "Marathon" / "Concert" / "Show" instead of "Event" on cards, the event page and
  the ticket, and an icon per kind (a runner, a music note, a theatre mask — Material icons
  `directions_run`, `music_note`, `theater_comedy` or the closest the app's icon set has).

## Part A — backend and admin panel

Backend (`backend`, read `backend/README.md`; base `src/main/java/com/ticket/app/backend/`):

1. `event/domain/EventKind` enum `MARATHON("marathon")`, `CONCERT("concert")`, `SHOW("show")`, `code()`,
   `fromCode` → invalid "Choose what kind of event it is.", and `needsRunnerDetails()` (marathon only).
2. The kind belongs to the event itself: a field on `Event` (publish, restore, accessor), `EventDraft`
   gets it, the `events` table gets a column. Keep the churn small: keep existing `restore` overloads
   where many callers use them, defaulting to CONCERT, as was done for `Booking.restore`.
3. Migration `V11__event_kinds.sql`: `alter table events add column kind text not null default 'concert'
   check (kind in ('marathon','concert','show'))`; set `marathon` for events whose page has
   `needs_runner_details`; then drop `event_pages.needs_runner_details`. `EventPage` loses the flag; every
   place that read it (`OnlineSaleService`, `CatalogService`, DTOs, seeder) uses `event.kind()` instead.
4. API: `POST /merchant/events` takes `kind` (required; missing or unknown → 400 with the message above);
   merchant event JSON, catalogue JSON and the buyer booking's `event` JSON carry `kind`. Keep
   `needsRunnerDetails` in the buyer JSON too (derived), so nothing breaks.
5. Demo data: Khmer Runners Club's three runs are marathons; Khmer Rock Night and the Siem Reap festival
   concerts; Laugh PP's comedy night a show; the cinema, bus and admission businesses' demo events
   concerts (they are not on sale to buyers anyway). Keep `SampleDataTest`'s match with the merchant app
   mock (it compares events/bookings data; check what it compares).
6. README: the API table and the "Buyers" section.
7. Do NOT run or write backend tests; only compile (`test-compile`). Existing test code that calls changed
   constructors must still compile — fix only what the compiler needs, nothing else in tests.

Admin panel (`admin-panal`, Vue 3 + TS, read its README):

8. Payouts page (`src/views/PayoutsView.vue`, `src/api/types.ts`): owed and paid rows read `refundsCents`
   (0 when missing) and show a "Refunds" column (−$X, or "—" when 0); the "Mark as paid" confirmation
   text says "… minus $C commission minus $R refunds" when there are refunds. Dashboard's owed card the
   same if it shows the breakdown. Update the panel's tests (`npm test`, vitest) and run `npm run
   typecheck` and `npm test`.
9. Events page: show the kind next to the event name (small label), from the admin events JSON — add
   `kind` to `GET /admin/events` in the backend (admin module) for this.

## Part B — merchant app (`merchant-app`)

1. Create event: a required "What kind of event?" choice with three chips (Marathon, Concert, Show),
   above the ticket types; Publish stays disabled until one is chosen; sent as `kind`. The mock backend
   stores it and requires it like the server. The event entity and JSON get `kind`.
2. Show the kind where events are listed for the owner (Today's live/upcoming/past cards and the event
   chips in Bookings may stay as they are if there is no room — at least the event's own header or
   details). Keep it small.
3. Mock demo events: the same kinds as the server's demo (Part A point 5).
4. The polled-resource race (also in this app, `core/network/polled_resource.dart`): a poll that started
   before `update()` must not replace the newer list (drop answers of polls started before the last
   update, e.g. with a generation counter, or poll again right after an update). Test it.
5. README. Run `flutter analyze` and `flutter test` (Flutter is not on PATH: PowerShell
   `Push-Location D:\vscode_file\ticket-app\merchant-app; & 'D:\flutter\bin\flutter.bat' analyze;
   & 'D:\flutter\bin\flutter.bat' test; Pop-Location`).

## Part C — user app (`user-app`)

1. `EventListing` gets `kind` (enum marathon/concert/show); `needsRunnerDetails` becomes `kind ==
   marathon` (remove the separate field or derive it). JSON reads `kind` (fall back to `needsRunnerDetails`
   → marathon, else concert, for an older server). Mock catalogue: ev1 Khmer Rock Night and ev3 Angkor
   Sunset Music Fest concerts, ev2 the half marathon a marathon, ev4 Laugh PP a show.
2. Label and icon per kind everywhere an event shows its category (cards, the event page, checkout's
   summary, the ticket, Activity): "Marathon" / "Concert" / "Show" and the icons above.
3. The event page hides an empty "About" section and an empty policy bullet in "Good to know" (seen with a
   merchant-created event: an "About" heading with nothing under it and an empty bullet).
4. The four fixes from the step 4 review:
   - `features/booking/presentation/organisms/ticket_card.dart` ~121: hide the QR code and the scan hint
     whenever the booking is cancelled (status), not only when cancellation details exist; with no details
     show a plain "Cancelled by the organiser." line.
   - `core/network/polled_resource.dart`: the same race fix as Part B point 4 (a booking just placed must
     not vanish when an older poll answers). Test it.
   - `user-app/README.md` ~32: the bookings list is polled every 15 s from the first visit to Activity
     until sign-out (not only while Activity is open) — say so, or pause polling while the app is in the
     background; choose the simpler correct option.
   - `features/booking/data/repositories/api_booking_repository.dart` ~34: the "coming soon" message for a
     non-event order names its category (bus, cinema or admission).
5. README. Run `flutter analyze` and `flutter test` (same PowerShell form, in `user-app`). Keep
   `test/widget_test.dart` (clock stopped at 08:00, 15 Nov 2026) passing.

## Rules from the user (every part)

- Change files only with the Edit/Write tools, one file at a time; the user approves each change. No
  shell edits (sed, redirects, cp, tee).
- No backend tests (don't run or write them). App tests and the admin panel's tests are fine.
- No commits, no package installs, no deleting files. Touch only the projects of your part.
