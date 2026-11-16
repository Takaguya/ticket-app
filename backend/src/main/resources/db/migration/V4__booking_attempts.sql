-- Answers can be lost: the server saves a check-in or a door sale, then crashes or the
-- connection drops before the app hears back. The app sends the same attempt ID when it
-- tries again, and the server answers with what it already did, instead of refusing a
-- guest it just admitted ("already checked in") or recording a cash sale twice.
create table booking_attempts (
    attempt_id  uuid primary key,
    kind        text not null check (kind in ('checkIn', 'doorSale')),
    booking_id  text not null references bookings (id) on delete cascade,
    staff_id    uuid not null references staff_members (id),
    created_at  timestamptz not null default now()
);
