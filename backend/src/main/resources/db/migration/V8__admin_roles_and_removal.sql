-- Two kinds of admin: super admins add and remove admins; admins do everything else.
-- Admins added on the server (the first admin, the demo admin) become super admins;
-- admins added in the panel stay admins.
alter table admins add column role text not null default 'admin' check (role in ('super_admin', 'admin'));
update admins set role = 'super_admin' where added_by is null;

-- A removed admin is kept, because payouts point to the admin who made them, but
-- cannot sign in and is no longer listed.
alter table admins add column removed_at timestamptz;
alter table admins add column removed_by uuid references admins (id);

-- A removed admin's address can be given to a new admin.
alter table admins drop constraint admins_email_key;
create unique index admins_email on admins (email) where removed_at is null;
