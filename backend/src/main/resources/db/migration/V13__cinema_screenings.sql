-- Cinema screenings: a cinema (a business of type cinema) publishes one screening at a time. A
-- screening is an event of kind 'cinema' (so approval, bookings, check-in, payouts and cancelling
-- work as for any event) with these extras. The event's name is the film, its venue the cinema,
-- the event page's venue_detail where the cinema is and its about text the film's synopsis. It
-- has one ticket type, "Seat", and as many seats as the hall has.

alter table events drop constraint events_kind_check;
alter table events add constraint events_kind_check
    check (kind in ('marathon', 'concert', 'show', 'bus', 'cinema'));

create table screenings (
    event_id         uuid primary key references events (id) on delete cascade,
    -- The film, as the user app lists it: screenings with the same title are the same film.
    film_title       text not null check (length(film_title) between 1 and 100),
    rating           text not null default '' check (length(rating) <= 10),
    genre            text not null default '' check (length(genre) <= 30),
    runtime_minutes  int  not null check (runtime_minutes between 10 and 600),
    hall             text not null check (length(hall) between 1 and 40),
    -- Decides the seat layout: small 6 x 8, standard 8 x 10, large 10 x 12.
    hall_size        text not null check (hall_size in ('small', 'standard', 'large'))
);

-- Hall seats are a row letter and a number (F5); coach seats a number and a letter (3A).
alter table booking_seats drop constraint booking_seats_seat_id_check;
alter table booking_seats add constraint booking_seats_seat_id_check
    check (seat_id ~ '^([0-9]{1,2}[A-D]|[A-J][0-9]{1,2})$');
