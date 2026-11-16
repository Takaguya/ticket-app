# Step 2 hand-off: the backend buyer API

For `code-writer`. The task and the user's decisions: `docs/tasks/2026-11-15-buyer-api-and-merchant-cancel.md`.
Read `backend/README.md` first. Follow the existing code exactly: module/layer layout, javadoc tone,
records and enums with `code()`, `BusinessRuleException.invalid/conflict`, `NotFoundException`, JdbcClient
SQL in `infrastructure`, `SqlTime`, times in JSON local to Pin's time zone without offset
(`LocalDateTime`, whole seconds), money in whole US cents. Look at the class named as the model for
each new one and copy its shape.

Base path: `backend/src/main/java/com/ticket/app/backend/` (below: `…/`).

## Design in short

- New module **`buyer`** (domain, application, infrastructure; no web): a buyer's account. It depends on
  `shared` only. `identity -> buyer` (sign-in, sessions) and `booking -> buyer` (bookings by a buyer).
- Buyer sessions are a third kind, kept apart like admin sessions: own table, principal `Buyer`,
  authority `ROLE_BUYER`. Buyer endpoints are under `/buyer/**` and `/catalog/**`.
- Buyer-facing event details (venue detail, about, policy, race flag, ticket type notes) live in a new
  optional record per event, `EventPage`, so `Event`, `TicketType` and the merchant API stay unchanged.
- Online sales live in `booking`, like door sales: `Booking.boughtOnline`, `OnlineSaleService`.
- Not in this step: retries with an attempt ID for online orders (note it in README "Next"); bus, cinema,
  admission; buyers cancelling; backend tests (the user said no backend tests yet — do not write or run
  any, except the `ArchitectureTest` rule change below).

## 1. Migration `src/main/resources/db/migration/V10__buyers_and_online_bookings.sql`

Header comment in the style of V5/V9. Tables and changes:

- `buyers`: `id uuid pk default uuidv7()`, `phone text not null unique` (same E.164 check as
  `staff_members.phone`), `name text not null check (length(name) between 1 and 80)`,
  `gender text not null check (gender in ('female','male','other'))`, `date_of_birth date not null`,
  `email text` (nullable, `length(email) <= 254`), `created_at timestamptz not null default now()`.
- `buyer_sessions`: like `admin_sessions` (V5): `token_hash bytea pk`, `buyer_id uuid not null references
  buyers (id) on delete cascade`, `created_at`, `expires_at`; index on `buyer_id`.
- `event_pages`: `event_id uuid pk references events (id) on delete cascade`,
  `venue_detail text not null default ''` (≤ 120), `about text not null default ''` (≤ 2000),
  `policy text not null default ''` (≤ 200), `needs_runner_details boolean not null default false`,
  `ticket_type_notes text[] not null default '{}'` — one per ticket type, in `ticket_types.position`
  order; a missing entry means no note.
- `bookings`: `add column buyer_id uuid references buyers (id)`, `add column promo_code text`,
  `add column discount_cents bigint not null default 0 check (discount_cents >= 0)`; constraints
  `buyer_id is null or channel = 'online'` and `promo_code is not null or discount_cents = 0`; partial
  index `bookings_buyer on bookings (buyer_id) where buyer_id is not null`.
- `booking_runners`: `booking_id text pk references bookings (id) on delete cascade`, `name`, `phone`,
  `email` (nullable), `gender` (same check as buyers), `age smallint check (age between 5 and 99)`,
  `nationality`, `emergency_name`, `emergency_phone`, `shirt_size text check (shirt_size in
  ('XS','S','M','L','XL'))`; all `not null` except `email`.
- `saved_runners`: `buyer_id uuid pk references buyers (id) on delete cascade`, the same runner columns,
  `saved_at timestamptz not null`.

## 2. Module `buyer`

- `…/buyer/domain/BuyerId.java` — copy `business/domain/StaffId.java` (UUID record, `newId()`, `parse`
  answering NotFound "This account does not exist.").
- `…/buyer/domain/Gender.java` — enum `FEMALE("female")`, `MALE("male")`, `OTHER("other")`, `code()`,
  `fromCode` → invalid "Choose your gender.".
- `…/buyer/domain/Buyer.java` — final class (id, name, phone `PhoneNumber`, gender, dateOfBirth
  `LocalDate`, email `EmailAddress` nullable). `static Buyer register(PhoneNumber phone, String name,
  Gender gender, LocalDate dateOfBirth, String email, LocalDate today)` validates like the user app's
  registration (read `user-app/lib/features/auth/presentation/bloc/register/` and
  `user-app/lib/features/auth/data/datasources/auth_mock_data_source.dart` `register`, and use the same
  messages); at least: name stripped, 1–80 ("Enter your name." / "Keep your name under 80 characters."),
  gender required, date of birth required and not in the future, blank email = none, otherwise
  `EmailAddress.of` (check `shared/domain/EmailAddress.java` for its API and message). `restore(...)` for
  storage. Accessors; `email()` returns `Optional<EmailAddress>`.
- `…/buyer/domain/BuyerRepository.java` — `Optional<Buyer> find(BuyerId)`, `Optional<Buyer>
  findByPhone(PhoneNumber)`, `boolean tryAdd(Buyer)` (false when the phone already has an account).
- `…/buyer/application/BuyerService.java` — `@Service`. `Buyer register(PhoneNumber, String name, Gender,
  LocalDate dateOfBirth, String email)` (today from the `Clock`; conflict "This number already has a Pin
  account. Please sign in." when `tryAdd` is false), `Optional<Buyer> withPhone(PhoneNumber)`,
  `Optional<Buyer> find(BuyerId)`.
- `…/buyer/infrastructure/JdbcBuyerRepository.java` — copy the style of
  `business/infrastructure/JdbcStaffRepository.java`; `tryAdd` uses `on conflict (phone) do nothing`.

## 3. `identity`: buyer sign-in and sessions

- `…/identity/domain/BuyerSession.java` — like `Session` with `BuyerId buyerId`; `start(BuyerId, Instant,
  Duration)` → `Started(SecretToken, BuyerSession)`; `isActiveAt`.
- `…/identity/domain/BuyerSessionRepository.java` — `add`, `find(TokenHash)`, `remove(TokenHash)`,
  `int removeExpired(Instant)`.
- `…/identity/infrastructure/JdbcBuyerSessionRepository.java` — copy `JdbcAdminSessionRepository`.
- `…/identity/application/BuyerSignedIn.java` — `record BuyerSignedIn(SecretToken accessToken, Buyer buyer)
  implements VerifyResult`. Add it to `VerifyResult`'s `permits`.
- `…/identity/application/BuyerSessionService.java` — `@Service`: `BuyerSignedIn start(Buyer)` (TTL
  `properties.sessionTtl()`), `Optional<Buyer> resolve(String accessToken)` (active session, buyer still
  exists), `void end(String accessToken)`.
- `…/identity/application/SignInService.java`:
  - `verify(String phone, String code, SignInApp app)`; new enum `…/identity/application/SignInApp`
    (`MERCHANT("merchant")`, `USER("user")`, `fromCode`, null/blank → MERCHANT so today's callers keep
    working). For USER: `buyers.withPhone(phone)` → `buyerSessions.start`, else `newNumber(...)`.
    MERCHANT is today's behaviour.
  - `@Transactional BuyerSignedIn registerBuyer(String registrationToken, String name, Gender gender,
    LocalDate dateOfBirth, String email)`: `usableRegistration`, `buyers.register(registration.phone(),
    ...)`, remove the token, start the session. Validation failures must not use up the token: register
    first, remove the token after (or catch and rethrow) — a person who mistyped their name can fix it
    and send again.
- `…/identity/application/SignInHousekeeping.java` — also `buyerSessions.removeExpired(now)` in the count.
- `…/identity/web/SessionAuthenticationFilter.java` — after the staff lookup and before the admin one:
  `token.flatMap(buyerSessions::resolve)` → principal `Buyer`, authority `ROLE_BUYER`. Constructor gets
  `BuyerSessionService`; update the class javadoc.
- `…/identity/web/SecurityConfig.java`:
  - `PUBLIC_POSTS` adds `/buyer/register`.
  - before `anyRequest()`: `requestMatchers(HttpMethod.POST, "/auth/sign-out").hasAnyRole("OWNER",
    "SCANNER", "BUYER")`, `requestMatchers("/buyer/**", "/catalog/**").hasRole("BUYER")`.
  - access denied: on `/buyer/**` or `/catalog/**` answer 403 "Sign in with the Pin app to do this.";
    keep the others as they are. Pass the new service to the filter. Update the class javadoc.
- `…/identity/web/AuthController.java` — `verify` passes `SignInApp.fromCode(request.app())`;
  `signOut` ends the token in both `sessions` and `buyerSessions` (removing an unknown hash is harmless).
- `…/identity/web/AuthDtos.java` — `VerifyResponse.of` handles `BuyerSignedIn` →
  `new VerifyResponse(BuyerSessionResponse..., null)`: make `session` typed `Object` or add a second
  nullable field? Keep the JSON `{"session": {"accessToken", "user": {...}}}` for both apps; for buyers
  `user` is `BuyerResponse {id, name, phone, gender, dateOfBirth (yyyy-MM-dd), email (null if none)}`.
  Simplest: `record VerifyResponse(Object session, String registrationToken)`.
- `…/identity/web/BuyerAuthController.java` (new) — `POST /buyer/register {registrationToken, name,
  gender, dateOfBirth, email}` → 201 `{accessToken, user: BuyerResponse}`; `GET /buyer/me` →
  `BuyerResponse` (`@AuthenticationPrincipal Buyer me`). Request/response records in `AuthDtos` (or a new
  `BuyerAuthDtos`). `dateOfBirth` as `LocalDate` (`2001-04-12`); a missing one → 400 "Enter your date of
  birth." (`@NotNull`).

## 4. `event`: what buyers see

- `…/event/domain/EventPage.java` — record `(EventId eventId, String venueDetail, String about, String
  policy, boolean needsRunnerDetails, List<String> ticketTypeNotes)`; `static EventPage blank(EventId)`;
  `String noteFor(int ticketTypeIndex)` ("" when missing). Strip text, null → "".
- `…/event/domain/EventPageRepository.java` — `Optional<EventPage> find(EventId)`, `Map<EventId,
  EventPage> findAll(Collection<EventId>)`, `void save(EventPage)` (insert or replace).
- `…/event/infrastructure/JdbcEventPageRepository.java`.
- `…/event/application/EventOnSale.java` — record `(Event event, EventPage page, String organiser)`.
- `…/event/application/CatalogService.java` — `@Service`:
  - `List<EventOnSale> onSale()`: every event that is approved, of a business that is `ACTIVE` and of
    type `EVENTS`, starting after now (`LocalDateTime.now(clock)`), soonest first; page from the
    repository or `EventPage.blank`; organiser = business name (`BusinessService.find`).
  - `EventOnSale onSale(EventId)`: the same rules for one; unknown → NotFound "This event does not
    exist."; not on sale → NotFound "This event is no longer on sale.".
  - `@Transactional(propagation = MANDATORY) EventOnSale lockOnSale(EventId)`: locks the event row
    (`EventRepository.findAndLock`, as `EventService.lockEventOf` does), then the same rules, but "not on
    sale" is a conflict (409) "This event is no longer on sale." — the buyer had it on screen.
  - `EventOnSale details(EventId)` for an event a buyer already booked, whatever its state now (ended,
    business suspended): the event, its page or blank, the organiser.
- `…/event/web/CatalogController.java` + `…/event/web/CatalogDtos.java` — `GET /catalog/events` and
  `GET /catalog/events/{eventId}` → `EventListingResponse {id, name, startsAt, venue, venueDetail, about,
  organiser, policy, needsRunnerDetails, ticketTypes: [{name, description, priceCents}]}`.

## 5. `booking`: buying online and the buyer's bookings

Domain:
- `…/booking/domain/ShirtSize.java` — enum XS, S, M, L, XL; `code()` is the label (`"XS"`); `fromCode`
  → invalid "Choose a T-shirt size.".
- `…/booking/domain/Runner.java` — record `(String name, PhoneNumber phone, EmailAddress email /*nullable*/,
  Gender gender, int age, String nationality, String emergencyName, PhoneNumber emergencyPhone,
  ShirtSize shirtSize)`, validated in the compact constructor with the user app's messages (read
  `user-app/lib/features/booking/presentation/bloc/runner_details/` and
  `.../organisms/runner_form.dart`); at least name and nationality and emergency name required, age 5–99.
- `…/booking/domain/Promotion.java` — record `(String code, String title, String description, int
  percentOff, Money amountOff, Money minimumSpend)`; `matches(String typed)` (strip, ignore case),
  `appliesTo(Money subtotal)` (above zero and ≥ minimum), `discountOn(Money subtotal)` (percent of the
  subtotal, rounded like `Money.percent`, plus `amountOff`, at most the subtotal).
- `…/booking/domain/Promotions.java` — `static final List<Promotion> ON_OFFER` = `D2D10` "10% off
  tickets" / "Any category" / 10%; `FIRST` "$2 off" / "Orders of $5 or more" / $2.00 off / minimum
  $5.00 (exactly as `user-app/lib/mock_backend/mock_bookings.dart`); `Optional<Promotion> find(String)`.
- `…/booking/domain/OnlinePurchase.java` — record `(BuyerId buyer, String promoCode /*nullable*/, Money
  discount, Runner runner /*nullable*/)`: what only an online booking made in the Pin app has.
- `…/booking/domain/Booking.java`:
  - field `OnlinePurchase purchase` (null for door sales and the demo's sample bookings); new full
    `restore(..., Cancellation cancellation, OnlinePurchase purchase, Instant createdAt)`; the existing
    `restore` overloads delegate with `null`.
  - `static Booking boughtOnline(BookingId id, Event event, boolean needsRunner, Buyer buyer,
    List<BookingLine> lines, PaymentMethod payment, String promoCode, Runner runner, SalesSummary sales,
    Instant now)`. Rules, in this order, with these messages: payment must be `ABA_KHQR` or `CARD`
    ("Choose how to pay."); at least one ticket ("Choose at least one ticket."); at most 8 ("Maximum 8
    tickets per booking."); each ticket type once ("List each ticket type once."); known ticket types,
    left per event and per ticket type — reuse the door sale's messages by moving the shared checks and
    pricing into one private helper used by both factories; `needsRunner` and no runner → invalid "Add
    the runner's details." (a runner for a non-race is dropped); promo: unknown → invalid "<CODE> is not a
    valid promo code." (as typed, upper-cased), not applying → invalid "<CODE> needs an order of $5.00 or
    more." (minimum with `Money.toDisplayString`). total = subtotal − discount. `buyerName` = runner's
    name, else the buyer's; `phone` = the buyer's; `tshirtSizes` = the runner's size once, else empty;
    channel ONLINE, status OPEN.
  - `purchase()` accessor; `Money discount()` (zero without purchase); `Money subtotal()` = total +
    discount; `boolean isBoughtBy(BuyerId)`.
- `…/booking/domain/BookingRepository.java` — `List<Booking> findByBuyer(BuyerId)`.
- `…/booking/domain/SavedRunnerRepository.java` — `Optional<Runner> find(BuyerId)`, `void save(BuyerId,
  Runner, Instant savedAt)`.

Infrastructure:
- `JdbcBookingRepository` — read `buyer_id`, `promo_code`, `discount_cents` and the runner (left join
  `booking_runners`, or a second query per list like the lines) into `OnlinePurchase` when `buyer_id` is
  set; `tryAdd` writes them and inserts the runner row; `findByBuyer` via `findWhere("b.buyer_id = :id")`.
- `…/booking/infrastructure/JdbcSavedRunnerRepository.java` — upsert on `buyer_id`.

Application:
- `…/booking/application/OnlineOrder.java` — record `(EventId eventId, List<BookingLine> lines,
  PaymentMethod payment, String promoCode, Runner runner, boolean saveRunner)`.
- `…/booking/application/OnlineSaleService.java` — copy `DoorSaleService`: `@Transactional Booking
  buy(Buyer buyer, OnlineOrder order)`: `catalog.lockOnSale(order.eventId())`, `SalesSummary.of(event,
  bookings.findByEvent(...))`, up to 20 ID draws with `Booking.boughtOnline` + `tryAdd`; then, if
  `saveRunner` and a runner was used, `savedRunners.save`. Javadoc: payment is simulated — Pin takes no
  real money yet.
- `…/booking/application/BuyerBooking.java` — record `(Booking booking, EventOnSale event)`.
- `…/booking/application/BuyerBookingService.java` — `List<BuyerBooking> bookingsOf(Buyer)` (soonest
  event first), `BuyerBooking bookingOf(Buyer, BookingId)` (NotFound "This booking does not exist." when
  missing or not theirs), `Optional<Runner> savedRunner(Buyer)`, `List<Promotion> promotions()`. Events
  through `CatalogService.details`.

Web:
- `…/booking/web/BuyerBookingController.java` + `…/booking/web/BuyerBookingDtos.java`:
  - `GET /buyer/promotions` → `[{code, title, description, percentOff, amountOffCents,
    minimumSpendCents}]`.
  - `GET /buyer/runner` → `{runner: RunnerJson | null}`.
  - `POST /buyer/bookings {eventId, lines: [{ticketType, quantity}], payment, promoCode?, runner?,
    saveRunner?}` → 201 `BuyerBookingResponse`. `payment` uses the API's names, `abaKhqr` or `card` (the
    user app maps its ABA Pay to `abaKhqr`). `RunnerJson {name, phone, email, gender, age, nationality,
    emergencyName, emergencyPhone, shirtSize}`; phones through `PhoneNumber.of`.
  - `GET /buyer/bookings` → `[BuyerBookingResponse]`; `GET /buyer/bookings/{bookingId}` → one (404 when
    the ID is malformed, unknown or another buyer's).
  - `BuyerBookingResponse {id, status, holderName, payment, promoCode, discountCents, subtotalCents,
    totalCents, bookedAt, lines: [{ticketType, quantity, unitPriceCents}], event: {id, name, startsAt,
    venue, venueDetail, about, organiser, policy, needsRunnerDetails, ticketTypes: [{name, description,
    priceCents}]}, runner: RunnerJson | null, cancellation: {at, reason, businessName, refundCents} |
    null}`. Unit prices come from the event's ticket types (events cannot be edited after publishing).
    `cancellation` only when `booking.cancellation()` is set; `businessName` = organiser.
- `GET /merchant/...` stays as it is: buyer bookings appear there already as online bookings.

## 6. Demo data (`…/demo/`)

- `DemoDataSeeder`: a fixed buyer, created once like the staff (`on conflict do nothing`): id
  `50000000-0000-7000-8000-000000000001`, `+85510222333`, Sokha Chan, female, 1996-04-12,
  `sokha.chan@example.com`.
- Event pages for every demo event (created with the events, so the daily reset recreates them; they go
  with `on delete cascade`): Khmer Runners Club's three runs `needsRunnerDetails = true`, venue details,
  about and policy in the style of the user app's mock half marathon (`mock_catalog.dart` `ev2`); PP Live
  Events' Khmer Rock Night, Laugh PP's comedy night and the Siem Reap festival from `ev1`, `ev4`, `ev3`;
  ticket type notes where the mock has descriptions. Put the texts in `SampleData`/`DemoMerchants` next to
  the events.
- Sokha's booking, made after the Kampot sample bookings: 1× 10K for the Kampot River Run, runner = Sokha
  (phone hers, emergency contact "Dara Chan" +85512777888, shirt M, Cambodian, her age), paid `abaKhqr`,
  booked a day before now, built with `Booking.restore` and a fixed ID that `tryAdd` saves (log a warning
  if it is taken). Keep `SampleData.bookings(...)` unchanged so `SampleDataTest` (the merchant app mock
  match) still holds.
- Log line at startup: add the demo buyer's number.

## 7. `ArchitectureTest` (src/test) and README

- `ArchitectureTest`: add the `buyer` module and the dependencies `identity -> buyer`, `booking -> buyer`;
  `buyer` uses only `shared`. Only change the rules; don't run the tests.
- `backend/README.md`: the "Run it" demo table (buyer number), the API table (new endpoints, `app=user`
  on verify, `cancellation`/`refundsCents` from step 1), a "Buyers (user app)" section (catalogue rules,
  checkout refusals, promo codes, runner, simulated payment), Security (buyer sessions apart), code layout
  (`buyer` module), dependency rules, "Next" (attempt IDs for online orders, bus/cinema/admission,
  merchant screens for event pages).

## Rules from the user

- Change files only with the Edit/Write tools, one file at a time; the user approves each change. No
  shell edits (sed, redirects, cp).
- Compile when done: PowerShell `Push-Location D:\vscode_file\ticket-app\backend; $env:JAVA_HOME =
  'C:\Program Files\Java\jdk-26.0.1'; .\mvnw.cmd -o -q test-compile; Pop-Location`. Do not run tests.
- No commits, no package installs, no deleting files.
- Don't touch the Flutter apps or the admin panel.
