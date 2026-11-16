# Admission tickets: places (2026-11-16)

Round after bus trips and cinema screenings. Same approach: the main session builds backend,
then merchant app, user app and admin panel, with backend tests on. No agents.

## Decisions (the user's, 2026-11-16)

- A **place** (temple park, water park, wildlife centre...) is published **once** by an
  **Admission** business and is **open every day**. Buyers pick any day in the next 62 days;
  the ticket is good for that whole day. The merchant does no per-day work.
- **Optional daily limit per ticket type.** The merchant may set "max per day" on a ticket
  type, or leave it unlimited. The server never sells past it for a given day.
- Only Admission-type businesses publish places; an Admission business no longer publishes
  ordinary events.
- Backend tests are on.

My choices (not asked): a ticket is only valid on its visit day (check-in refused on any other
day, with a message saying which day it is for); an owner can cancel a booking until its visit
day has passed; door sales are for today; 1 to 6 ticket types per place like events; at most
8 tickets per booking.

## Design

- A place is an **event of kind `admission`** (approval, bookings, check-in, payouts, cancel and
  refund, admin pages all work as for any event). The event's name is the place, its venue the
  place's name or site, the event page holds `venue_detail` (where it is), `about`, `policy` and
  a note per ticket type (the user app's "description").
- `events.starts_at` is the day it was published: a placeholder. An admission event is **never
  past**: `Event.timingOn` is always today, so it can be approved and sold at any time, and the
  admin panel shows it as live once approved.
- A ticket type's `quantity` is its **daily limit**. "No limit" is `TicketType.NO_LIMIT`
  (100,000, the existing maximum): the API sends `dailyLimit: null` for it.
- `bookings.visit_date` (V14): set for admission bookings, null otherwise. Sale checks count
  only the bookings of the visit day (`SalesSummary.of(event, bookings)` over the day's
  bookings; `BookingRepository.findByEventVisiting`).
- Buyer booking: `POST /buyer/bookings {eventId, lines, payment, promoCode?, visitDate}`; the
  booking JSON has `visitDate`.
- Catalogue (buyers only): `GET /catalog/places`, `GET /catalog/places/{id}`,
  `GET /catalog/places/{id}/availability?date=` (what is left per ticket type that day).
  `GET /catalog/events` no longer lists places.
- Merchant: `POST /merchant/events/places {name, venue, venueDetail?, about?, policy?,
  ticketTypes: [{name, description?, priceCents, dailyLimit?}]}`; `visitDate` in the booking
  JSON; the Today numbers of a place are today's visits.
- Check-in: a booking's `visitDate` must be today (409 otherwise).
- Demo: Angkor Enterprise (active Admission business) with the user app mock's Angkor pass (and Wildlife Alliance with Phnom Tamao) and
  bookings over the coming days (`demo/DemoPlaces.java`); Garden City (waiting for approval)
  keeps its one place.

## Steps

1. Backend: V14, `EventKind.ADMISSION`, `TicketType.NO_LIMIT`, `Event` timing, `Booking.visitDate`,
   repository, sale / door / check-in / cancel / summary services, place catalogue, merchant
   publish endpoint, admin status, demo data, tests, README.
2. Merchant app: Create place form, Today for Admission businesses, visit date on bookings.
3. User app: places on the server, day + availability, order with `visitDate`, booking JSON.
4. Admin panel: "Place" label, daily numbers.
5. Full test suites; emulator run: publish, approve, book, check-in.

Not built (unless asked): editing a place's prices or closing days, blocking a day, a
"sold out" calendar view, snacks for cinema, booking for someone else.
