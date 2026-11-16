-- A cover image for an event, bus trip, screening or place: shown on the user app's cards, the
-- event page and the e-ticket, and in the merchant app and the admin panel. At most one per event.
--
-- The picture itself is kept here, in its own table, so listing events never reads it. What is
-- stored is the processed picture (a JPEG, at most 1280 pixels on its longest side), not the
-- upload. updated_at changes whenever the picture does: it is the version in the picture's URL,
-- so a changed picture is fetched again while an unchanged one is cached for a year.

create table event_images (
    event_id     uuid primary key references events (id) on delete cascade,
    content_type text        not null,
    data         bytea       not null,
    updated_at   timestamptz not null
);
