-- Events a business publishes, and the bookings for them.
-- Money is in whole US cents. Times are instants; the app shows them in Pin's time zone.

create table events (
    id               uuid primary key,
    business_id      uuid not null references businesses (id),
    name             text not null check (length(name) between 3 and 100),
    starts_at        timestamptz not null,
    venue            text not null check (length(venue) between 1 and 120),
    -- Percent Pin keeps of online sales, fixed when the event is published.
    commission_rate  numeric(5, 2) not null check (commission_rate between 0 and 100),
    created_at       timestamptz not null default now()
);

create index events_business on events (business_id, starts_at);

-- 1 to 6 per event, in the order the owner entered them. Capacity is the sum of quantities.
create table ticket_types (
    event_id     uuid not null references events (id) on delete cascade,
    position     smallint not null,
    name         text not null check (length(name) between 1 and 40),
    price_cents  bigint not null check (price_cents >= 0),
    quantity     int not null check (quantity > 0),
    primary key (event_id, position),
    unique (event_id, name)
);

-- One purchase. A whole booking is admitted at once.
create table bookings (
    id                  text primary key check (id ~ '^TK[0-9]{8}$'),
    event_id            uuid not null references events (id),
    buyer_name          text not null,
    phone               text not null,
    total_cents         bigint not null check (total_cents >= 0),
    payment             text not null check (payment in ('abaKhqr', 'card', 'cash')),
    channel             text not null check (channel in ('online', 'door')),
    status              text not null check (status in ('open', 'checkedIn', 'cancelled')),
    tshirt_sizes        text[] not null default '{}',
    checked_in_at       timestamptz,
    checked_in_by       uuid references staff_members (id),
    -- Kept as written at the time, so the name stays right if the member is removed.
    checked_in_by_name  text,
    created_at          timestamptz not null,
    check ((status = 'checkedIn') = (checked_in_at is not null))
);

create index bookings_event on bookings (event_id);

-- Tickets of one type on a booking. ticket_type matches ticket_types.name of the event.
create table booking_lines (
    booking_id   text not null references bookings (id) on delete cascade,
    position     smallint not null,
    ticket_type  text not null,
    quantity     int not null check (quantity > 0),
    primary key (booking_id, position)
);
