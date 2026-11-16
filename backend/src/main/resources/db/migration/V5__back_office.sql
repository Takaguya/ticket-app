-- The back office: Pin's admins approve new businesses and events, can suspend a
-- business, and pay each business what Pin collected for it online.

-- A new business waits for an admin's approval before it can sell. Businesses that
-- already exist are trusted: they become active.
alter table businesses
    add column status text not null default 'active'
        check (status in ('pending', 'active', 'suspended'));
alter table businesses alter column status set default 'pending';

-- A new event goes on sale once an admin approves it. Events that already exist count
-- as approved when they were published.
alter table events add column approved_at timestamptz;
update events set approved_at = created_at;

-- Pin staff who run the back office. They sign in by phone number and code.
create table admins (
    id          uuid primary key default uuidv7(),
    phone       text not null unique check (phone ~ '^\+[1-9][0-9]{7,14}$'),
    name        text not null check (length(name) between 1 and 80),
    created_at  timestamptz not null default now()
);

-- Signed-in admin browsers. Kept apart from the merchant app's sessions, so a
-- merchant's token can never open the back office. Only a hash of the token is kept.
create table admin_sessions (
    token_hash  bytea primary key,
    admin_id    uuid not null references admins (id) on delete cascade,
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null
);

create index admin_sessions_admin on admin_sessions (admin_id);

-- Money Pin sent a business for its online sales, minus Pin's commission. A payout
-- covers exactly the bookings that point to it, so no sale is ever paid twice.
create table payouts (
    id                uuid primary key,
    business_id       uuid not null references businesses (id),
    gross_cents       bigint not null check (gross_cents >= 0),
    commission_cents  bigint not null check (commission_cents >= 0),
    net_cents         bigint not null,
    booking_count     int not null check (booking_count > 0),
    paid_at           timestamptz not null,
    paid_by           uuid not null references admins (id),
    -- Kept as written at the time, like checked_in_by_name.
    paid_by_name      text not null,
    check (net_cents = gross_cents - commission_cents)
);

create index payouts_business on payouts (business_id, paid_at desc);

alter table bookings add column payout_id uuid references payouts (id);

-- Finds what is still owed: online bookings not paid out yet.
create index bookings_unpaid on bookings (event_id) where payout_id is null and channel = 'online';
