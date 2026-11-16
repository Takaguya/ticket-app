# Step 3 hand-off: "Cancel booking" in the merchant app

For `code-writer`. The task and the user's decisions: `docs/tasks/2026-11-15-buyer-api-and-merchant-cancel.md`.
The app: `merchant-app` (Flutter, Android; clean architecture per feature, atomic design system, BLoC,
go_router, get_it, dio). Read `merchant-app/README.md` first and follow its rules (pages and blocs use
use cases only, only `lib/app/` reads the service locator, repositories return `Result` and never
throw). It runs on its in-memory mock (`lib/mock_backend/`) by default and on the server with
`--dart-define=USE_MOCK_API=false`. Both must behave the same.

## What the server now sends (backend steps 1 and 2, done)

See `backend/README.md` (API table, "Buyers" section) and `backend/.../booking/web/BookingDtos.java`.

- `POST /merchant/bookings/{id}/cancel {reason}` (owners only) → the booking. `reason`: `buyerAsked`,
  `eventChanged`, `soldByMistake`, `other`. 409 with a `message` when it is checked in ("This booking is
  checked in, so it can't be cancelled.") or the event has ended ("The event has ended."); cancelling a
  cancelled booking returns it unchanged.
- Every booking (lists, check-in results) has new fields, all nullable / optional:
  - `cancellation: {at, staffName, reason, refundCents}` — set when the business cancelled it.
    `refundCents` is what Pin paid back to the buyer (what they paid); 0 for a door sale, which the
    business pays back itself. Bookings cancelled before this existed (the demo's) have none.
  - `promoCode` — a Pin promo code the buyer used. Pin pays for it: `totalCents` is the full ticket
    price, which the business is paid on, so for a promo booking `refundCents` is less than `totalCents`.
  - `runner: {name, phone, email, gender, age, nationality, emergencyName, emergencyPhone, shirtSize}`
    — a race runner's details, for the whole team.
- `GET /merchant/payouts`: `due` and each `paid` entry have `refundsCents` (the business's share of
  paid-out bookings it cancelled since, taken back). `due.netCents` can be below zero while refunds are
  more than new sales.

## What to build

1. **Booking entity and JSON** (`lib/features/bookings/domain/entities/booking.dart`,
   `data/models/booking_json.dart` or its model): `cancellation` (an entity with at, staffName, a
   `CancelReason` enum with the labels "The buyer asked to cancel", "The event changed or was called
   off", "Sold by mistake", "Other reason", refundCents), `promoCode`, `runner` (an entity). All
   optional, parsed when present.
2. **Repository and use case**: `cancelBooking(bookingId, reason)` → `Result<Booking>` on the bookings
   repository interface; the API implementation calls the endpoint and maps errors like the other calls
   (a 409's `message` is shown as written); the bookings list updates at once (as this device's own
   check-ins do). New use case `CancelBooking`.
3. **Mock** (`lib/mock_backend/`): the same rules as the server — owners only, open bookings only,
   not after the event's day, idempotent, refund = total for online and 0 for door sales, records who
   and when. Do NOT change the sample-data generator (the backend's `SampleDataTest` checks the two
   match).
4. **Booking detail page** (`lib/features/bookings/presentation/pages/booking_detail_page.dart` and its
   bloc):
   - Owners see a "Cancel booking" button (danger style, design-system atoms) on an open booking whose
     event has not ended. Scanners never see it.
   - It opens a bottom sheet: "Why are you cancelling?" with the four reasons (one must be chosen),
     a line on the money — online: "Pin refunds the buyer in full, to how they paid."; door sale:
     "Give the buyer their $X back yourself." — and a confirm button "Cancel booking" with a busy state;
     errors shown in the sheet or a toast as the app does elsewhere.
   - A cancelled booking shows: "Cancelled by <staffName> · <date time>", the reason, and "Pin refunded
     the buyer $X" (online) or "Give the buyer their $X back" (door). A cancelled booking without
     cancellation details shows "Cancelled. Do not admit." (replace today's "Cancelled by the buyer. Do
     not admit.", which is no longer true).
   - When there is a runner: a "Runner" section with name, phone, email, gender, age, nationality,
     emergency contact (name and phone), T-shirt size — for the whole team.
   - When there is a promo code: "Promo <CODE> · paid by Pin" near the price.
5. **Scan result** for a cancelled booking (`lib/features/scan/presentation/pages/scan_result_page.dart`):
   add the reason when known.
6. **Finance / payouts** (`payouts_card.dart` and its data): read `refundsCents`. When `due.netCents` is
   below zero show "Owed to you $0.00" and a note "Refunds of $X are taken off your next payout." When
   refunds are above zero, the caption shows them ("$X sales minus $Y commission minus $Z refunds").
   Paid payouts show their refunds when not zero.
7. **CSV** (`bookings_csv.dart`): add the server CSV's runner columns (Runner, Runner phone, Runner email,
   Runner gender, Runner age, Runner nationality, Emergency contact, Emergency phone), in the same order
   as `backend/.../booking/web/BookingsCsv.java`, so the two files match; update that Java file's
   javadoc sentence about the columns only if the column lists then match.
8. **README** (`merchant-app/README.md`): the Screens table (booking detail: cancel, runner), "With the
   real server" (cancel endpoint), "What Pin's admins decide" (refunds taken off payouts).

## Checks

- `flutter analyze` and `flutter test` in `merchant-app` (Flutter is NOT on PATH: PowerShell
  `Push-Location D:\vscode_file\ticket-app\merchant-app; & 'D:\flutter\bin\flutter.bat' analyze;
  & 'D:\flutter\bin\flutter.bat' test; Pop-Location`). Add tests in the app's style: the mock's cancel
  rules, the bloc, the detail page's button for owner vs scanner, the payouts card with negative net.
  Widget tests run on a 360x780 screen: use `tester.scrollUntilVisible` for things below the fold; never
  `await bloc.close()` on a bloc still inside `emit.forEach` of an open stream (it hangs) — let a
  `BlocProvider(create:)` own it.
- Do not run or change backend tests.

## Rules from the user

- Change files only with the Edit/Write tools, one file at a time; the user approves each change. No
  shell edits (sed, redirects, cp).
- No commits, no package installs (use only packages already in `pubspec.yaml`), no deleting files.
- Don't touch `user-app`, `admin-panal` or the backend's Java code (except the one javadoc sentence in
  point 7).
