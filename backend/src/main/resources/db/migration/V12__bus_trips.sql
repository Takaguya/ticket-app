-- Bus trips: tour tickets to the provinces, sold by businesses of type bus. A trip is an event of
-- kind 'bus' (so approval, bookings, check-in, payouts and cancelling work as for any event) with
-- these extras. Its boarding point is the event's venue, the boarding address is the event page's
-- venue_detail and the description its about text. It has one ticket type, "Seat".

alter table events drop constraint events_kind_check;
alter table events add constraint events_kind_check check (kind in ('marathon', 'concert', 'show', 'bus'));

create table bus_trips (
    event_id          uuid primary key references events (id) on delete cascade,
    origin            text not null check (length(origin) between 1 and 60),
    destination       text not null check (length(destination) between 1 and 60),
    duration_minutes  int  not null check (duration_minutes between 10 and 1440),
    -- Decides the seat layout: seater 2+2, vip 2+1, sleeper 1+1.
    coach_type        text not null check (coach_type in ('seater', 'vip', 'sleeper')),
    -- On board, e.g. Wi-Fi, A/C, Snack; separated by chr(31) like event page notes.
    amenities         text[] not null default '{}'
);

-- Which seat of a trip each booking holds. A seat is held by at most one live booking: cancelling a
-- booking sets held to false, which frees the seat for another buyer.
create table booking_seats (
    booking_id        text not null references bookings (id) on delete cascade,
    event_id          uuid not null references events (id),
    seat_id           text not null check (seat_id ~ '^[0-9]{1,2}[A-D]$'),
    -- The passenger's gender, shown on the seat map to other buyers; unknown for door sales.
    passenger_gender  text check (passenger_gender in ('female', 'male', 'other')),
    held              boolean not null default true,
    primary key (booking_id, seat_id)
);

create unique index booking_seats_one_holder on booking_seats (event_id, seat_id) where held;
