-- Businesses, the people who work for them, and sign-in by phone number.
-- Phone numbers are stored in E.164 form, e.g. +85512345678.

create table businesses (
    id          uuid primary key default uuidv7(),
    name        text not null check (length(name) between 1 and 80),
    type        text not null check (type in ('events', 'bus', 'cinema', 'admission')),
    -- Six digits a new scanner types to join. The owner can replace it.
    join_code   text not null unique check (join_code ~ '^[0-9]{6}$'),
    created_at  timestamptz not null default now()
);

-- Owners and scanners. A phone number belongs to at most one current member.
-- Removed members are kept (removed_at is set) so past check-ins still name them.
create table staff_members (
    id           uuid primary key default uuidv7(),
    business_id  uuid not null references businesses (id),
    phone        text not null check (phone ~ '^\+[1-9][0-9]{7,14}$'),
    name         text not null check (length(name) between 1 and 80),
    role         text not null check (role in ('owner', 'scanner')),
    created_at   timestamptz not null default now(),
    removed_at   timestamptz
);

create unique index staff_members_current_phone on staff_members (phone) where removed_at is null;
create index staff_members_business on staff_members (business_id);

-- The latest sign-in code sent to a phone number. Only a hash of the code is kept.
create table otp_challenges (
    phone       text primary key,
    code_hash   bytea not null,
    sent_at     timestamptz not null,
    expires_at  timestamptz not null,
    attempts    int not null default 0
);

-- Proof that a phone number with no account was confirmed, valid while the
-- person fills in the register or join form. Only a hash of the token is kept.
-- attempts counts wrong join codes, so join codes cannot be guessed.
create table registration_tokens (
    token_hash  bytea primary key,
    phone       text not null,
    expires_at  timestamptz not null,
    attempts    int not null default 0
);

create index registration_tokens_phone on registration_tokens (phone);

-- Signed-in devices. The app holds the token; only its hash is stored, so a
-- leaked database cannot be used to sign in.
create table sessions (
    token_hash  bytea primary key,
    member_id   uuid not null references staff_members (id),
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null
);

create index sessions_member on sessions (member_id);
