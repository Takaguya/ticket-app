-- Admins sign in to the admin panel with their email address and a password, which Pin
-- checks itself. They no longer use a phone number and a texted code.

-- Everyone signs in again, with a password.
delete from admin_sessions;

alter table admins drop column phone;

-- The server keeps it in lower case, so an address belongs to one admin however it is
-- typed. Admins added before this have none until one is given to them
-- (pin.admin-account, or the demo data for the demo admin); until then they cannot
-- sign in.
alter table admins add column email text unique
    check (length(email) <= 254 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');

-- Each admin's password, as a BCrypt hash with its salt and cost inside; never the
-- password itself.
create table admin_passwords (
    admin_id        uuid primary key references admins (id) on delete cascade,
    password_hash   text not null,
    -- Wrong passwords in a row. Too many lock sign-in until locked_until.
    wrong_attempts  int not null default 0 check (wrong_attempts >= 0),
    locked_until    timestamptz
);
