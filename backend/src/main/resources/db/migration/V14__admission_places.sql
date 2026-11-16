-- Admission places: a business of type admission publishes a place (a temple park, a water park)
-- once and it is open every day. A place is an event of kind 'admission', so approval, bookings,
-- check-in, payouts and cancelling work as for any event. Its ticket types' quantities are daily
-- limits, and each booking is for one visit day.

alter table events drop constraint events_kind_check;
alter table events add constraint events_kind_check
    check (kind in ('marathon', 'concert', 'show', 'bus', 'cinema', 'admission'));

-- The day the tickets are good for. Null for every other kind of event.
alter table bookings add column visit_date date;

-- Counting what a place has sold on one day.
create index bookings_visit on bookings (event_id, visit_date) where visit_date is not null;
