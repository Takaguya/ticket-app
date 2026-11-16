# Task: cinema screenings

Asked 2026-11-16 right after bus trips: "continue the do on the cinemas ticket". The user's choices:

- A cinema publishes **one screening at a time**: film title, rating, genre, runtime, about, cinema/branch,
  hall, date, time, price. The user app groups screenings of the same film.
- **No snacks** this round (the user app skips its snack step with the server).
- **Fixed hall sizes**: Small (6 rows x 8 seats), Standard (8 x 10, as the app's design), Large (10 x 12).
- Only Cinema-type businesses publish screenings. Main session does it all (no agents). Backend tests on.

## Design (same shape as bus trips)

A screening is an event of kind `cinema` with a `screenings` row (film, rating, genre, runtime, hall, hall
size). One ticket type "Seat". Seats are named by row letter and number (`A1`..`H10`), held in
`booking_seats` (its seat-id check is widened). `SeatLayout` gets the three halls next to the three coaches.

API: `POST /merchant/events/screenings`; buyer `GET /catalog/cinema/films`,
`GET /catalog/cinema/films/{filmId}/showtimes?date=`, `GET /catalog/cinema/showtimes/{id}/seats`;
`POST /buyer/bookings {eventId, seats, payment, promoCode?}` as for bus. Buyer booking JSON gets
`event.screening`; merchant event JSON gets `screening`.

Steps: backend (V13, domain, services, controllers, demo screenings for Legend Cinema, tests, README),
merchant app (Create screening, seats on booking), user app (cinema on the server), admin label, a run on
the emulator.
