# Step 4 hand-off: the user app on the server (events)

For `code-writer`. The task and the user's decisions: `docs/tasks/2026-11-15-buyer-api-and-merchant-cancel.md`.
The app: `user-app` (Flutter, Android; clean architecture per feature, atomic design, BLoC, go_router,
get_it, dio — already in `pubspec.yaml`). Read `user-app/README.md` first and keep its rules. Today it
runs only on its in-memory mock (`lib/mock_backend/`). After this step, `--dart-define=USE_MOCK_API=false`
runs it on the Pin server for **events**; the mock stays the default and keeps working for everything.

The merchant app already does exactly this: copy its approach and code style rather than inventing one.
Look at `merchant-app/lib/core/config/`, `core/network/` (dio client, bearer token, `polled_resource.dart`),
`core/error/` (exceptions, failures, `guard`, how API error codes map to failures), its API data
sources/repositories, `app/di/injector.dart` (mock vs API by `USE_MOCK_API`) and its Android setup for
plain HTTP in debug builds (`android/app/src/*/AndroidManifest.xml`, network security config).

## The server's buyer API (done, reviewed)

Read `backend/README.md` (API table and "Buyers (user app)" section) and the DTOs:
`backend/src/main/java/com/ticket/app/backend/identity/web/AuthDtos.java`, `BuyerAuthController.java`,
`event/web/CatalogDtos.java`, `booking/web/BuyerBookingDtos.java`. In short:

- `POST /auth/otp {phone, purpose}`; `POST /auth/verify {phone, code, purpose, app: "user"}` →
  `{session: {accessToken, user}}` or `{registrationToken}`; `POST /buyer/register {registrationToken,
  name, gender, dateOfBirth (yyyy-MM-dd), email?}` → 201 `{accessToken, user}`; `GET /buyer/me`;
  `POST /auth/sign-out`. `user` = `{id, name, phone, gender, dateOfBirth, email}`.
- `GET /catalog/events`, `GET /catalog/events/{id}` (404 "This event is no longer on sale.").
- `GET /buyer/promotions`, `GET /buyer/runner` → `{runner | null}`.
- `POST /buyer/bookings {eventId, lines: [{ticketType, quantity}], payment: "abaKhqr" | "card",
  promoCode?, runner?, saveRunner?}` → 201 booking. The app's ABA Pay is `abaKhqr`.
- `GET /buyer/bookings`, `GET /buyer/bookings/{id}` → `{id, status (open|checkedIn|cancelled),
  holderName, payment, promoCode, discountCents, subtotalCents, totalCents, bookedAt, lines: [{ticketType,
  quantity, unitPriceCents}], event: {…same as the catalogue…}, runner, cancellation: {at, reason,
  businessName, refundCents} | null}`.
- Times are local to Pin's time zone without an offset; money in whole cents; errors `{code, message}` —
  show `message` for `rejected`; 401 means the session is gone.

## What to build

1. **Core**: config (`USE_MOCK_API` default true, `API_BASE_URL` default `http://10.0.2.2:8080`), the dio
   client with the saved session's bearer token, error mapping, a polled resource — all as in the
   merchant app. A 401 on any call signs the person out (as the merchant app does). Android: INTERNET
   permission for release, plain HTTP allowed in debug only, as in the merchant app.
2. **Auth**: an API implementation of `AuthRemoteDataSource` (`requestOtp`, `verifyOtp` with
   `app: "user"`, `register`, `signOut`) and the JSON models; gender codes `female|male|other`.
3. **Catalogue**: an API `CatalogRepository`. Events come from the server; search filters the event list
   in the app (name, venue, venue detail). Bus, cinema and admission are **not on sale yet** with the
   server: give the domain a way to say which categories are on sale (e.g. a repository method or a value
   the use cases read — choose the cleanest), and make the UI show them as "Coming soon": the Tickets hub
   and Home buttons show a "Soon" tag and don't open (Home already does this for Ride and Food — reuse
   it); sections for bus routes, films and places are hidden. The mock keeps all four on sale.
4. **Booking**: an API `BookingRepository`. `promotions`, `savedRunner`, `placeOrder` (event orders
   only; tier names as `ticketType`; the runner and `saveRunner`), `watchBookings` (polled, e.g. every
   15 s while watched, and updated at once after placing an order), `booking(id)`. Seats and snacks are
   unreachable with the server (no bus/cinema): return a clear failure. Map the server booking to the
   app's `Booking` with an `EventRequest` built from the embedded event (tiers by name, quantities from
   the lines, the runner).
5. **Status and cancellation on bookings** (both mock and server):
   - `Booking` gains a status (confirmed / used / cancelled — the server's open / checkedIn / cancelled)
     and an optional cancellation (when, reason, business name, refund cents). Buyer-facing reason
     labels: buyerAsked "You asked to cancel", eventChanged "The event changed or was called off",
     soldByMistake "Sold by mistake", other "Other reason".
   - Activity: a "Cancelled" badge on cancelled bookings (and "Used" on checked-in ones).
   - Ticket page: a cancelled ticket hides the QR code (it no longer admits anyone) and shows "Cancelled by
     <business> on <date>", the reason, and "Refunded $X to <ABA Pay | Card>". A used ticket says it was
     used.
   - Mock: give the demo account (010 222 333) one booking cancelled by its organiser so the screens can
     be seen without the server (e.g. Khmer Rock Night, cancelled by PP Live Events yesterday, reason
     eventChanged, refunded in full). Update the tests that count the demo bookings.
   - Buyers still cannot cancel themselves — don't add that.
6. **Injector**: mock or API by `USE_MOCK_API`, as in the merchant app.
7. **README** (`user-app/README.md`): how to run against the server, what works there (events) and what
   is "Coming soon", cancelled tickets, the demo buyer on the server (same number and code).

## Checks

- `flutter analyze` and `flutter test` in `user-app` (Flutter is NOT on PATH: PowerShell
  `Push-Location D:\vscode_file\ticket-app\user-app; & 'D:\flutter\bin\flutter.bat' analyze;
  & 'D:\flutter\bin\flutter.bat' test; Pop-Location`). Add tests in the app's style: JSON mapping of a
  server booking (incl. cancellation and runner), the API repositories with a fake HTTP adapter (see how
  the merchant app tests its API repositories), "Coming soon" categories, the cancelled ticket page, the
  mock's cancelled demo booking. The end-to-end `test/widget_test.dart` stops the clock at 08:00 on
  15 Nov 2026 — keep it passing. Widget tests run on 360x780: scroll before finding things below the
  fold; never `await bloc.close()` on a bloc still inside `emit.forEach` of an open stream.
- Do not run or change backend tests.

## Rules from the user

- Change files only with the Edit/Write tools, one file at a time; the user approves each change. No
  shell edits (sed, redirects, cp).
- No commits, no package installs (use only what is in `pubspec.yaml`), no deleting files.
- Don't touch `merchant-app`, `admin-panal` or the backend.
