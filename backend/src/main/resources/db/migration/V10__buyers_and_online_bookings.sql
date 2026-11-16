-- Buyers: people who book tickets in the user app. They sign in by phone number and
-- code like the merchant app's staff, but their sessions are kept apart, so a buyer's
-- token can never open the merchant app's endpoints or the back office. A booking
-- bought online now knows who bought it, what promo code it used and, for a race, who
-- runs.

create table buyers (
    id             uuid primary key default uuidv7(),
    phone          text not null unique check (phone ~ '^\+[1-9][0-9]{7,14}$'),
    name           text not null check (length(name) between 1 and 80),
    gender         text not null check (gender in ('female', 'male', 'other')),
    date_of_birth  date not null,
    email          text check (length(email) <= 254),
    created_at     timestamptz not null default now()
);

-- Signed-in user app devices. Only a hash of the token is kept.
create table buyer_sessions (
    token_hash  bytea primary key,
    buyer_id    uuid not null references buyers (id) on delete cascade,
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null
);

create index buyer_sessions_buyer on buyer_sessions (buyer_id);

-- What the user app's event page shows beyond what the merchant publishes. An event
-- without a row here shows blanks. ticket_type_notes has one note per ticket type, in
-- ticket_types.position order; a missing entry means no note.
create table event_pages (
    event_id              uuid primary key references events (id) on delete cascade,
    venue_detail          text not null default '' check (length(venue_detail) <= 120),
    about                 text not null default '' check (length(about) <= 2000),
    policy                text not null default '' check (length(policy) <= 200),
    needs_runner_details  boolean not null default false,
    ticket_type_notes     text[] not null default '{}'
);

-- Who bought a booking online, the promo code it used and the discount it got. The
-- total is what was paid, after the discount. Door sales and the demo's sample
-- bookings have none of these.
alter table bookings
    add column buyer_id        uuid references buyers (id),
    add column promo_code      text,
    add column discount_cents  bigint not null default 0 check (discount_cents >= 0);

alter table bookings add constraint bookings_buyer_online check (buyer_id is null or channel = 'online');
alter table bookings add constraint bookings_discount_has_promo check (promo_code is not null or discount_cents = 0);

-- Finds a buyer's bookings.
create index bookings_buyer on bookings (buyer_id) where buyer_id is not null;

-- The one runner of a race booking.
create table booking_runners (
    booking_id       text primary key references bookings (id) on delete cascade,
    name             text not null check (length(name) between 1 and 80),
    phone            text not null check (phone ~ '^\+[1-9][0-9]{7,14}$'),
    email            text check (length(email) <= 254),
    gender           text not null check (gender in ('female', 'male', 'other')),
    age              smallint not null check (age between 5 and 99),
    nationality      text not null check (length(nationality) between 1 and 60),
    emergency_name   text not null check (length(emergency_name) between 1 and 80),
    emergency_phone  text not null check (emergency_phone ~ '^\+[1-9][0-9]{7,14}$'),
    shirt_size       text not null check (shirt_size in ('XS', 'S', 'M', 'L', 'XL'))
);

-- The runner a buyer chose to save, so the next race starts filled in.
create table saved_runners (
    buyer_id         uuid primary key references buyers (id) on delete cascade,
    name             text not null check (length(name) between 1 and 80),
    phone            text not null check (phone ~ '^\+[1-9][0-9]{7,14}$'),
    email            text check (length(email) <= 254),
    gender           text not null check (gender in ('female', 'male', 'other')),
    age              smallint not null check (age between 5 and 99),
    nationality      text not null check (length(nationality) between 1 and 60),
    emergency_name   text not null check (length(emergency_name) between 1 and 80),
    emergency_phone  text not null check (emergency_phone ~ '^\+[1-9][0-9]{7,14}$'),
    shirt_size       text not null check (shirt_size in ('XS', 'S', 'M', 'L', 'XL')),
    saved_at         timestamptz not null
);
