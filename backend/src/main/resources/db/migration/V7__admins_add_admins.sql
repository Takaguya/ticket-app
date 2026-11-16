-- Admins add other admins in the admin panel. The new admin gets a temporary password,
-- shown once to the admin who added them, and must choose their own at first sign-in
-- before they can do anything else.
alter table admin_passwords add column must_change boolean not null default false;

-- Who added the admin. Null for admins added from the server settings or the demo data.
alter table admins add column added_by uuid references admins (id) on delete set null;
