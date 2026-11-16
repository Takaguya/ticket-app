-- The owner of a business can cancel a booking in the merchant app, with a reason the
-- buyer is shown. Pin refunds a booking bought online in full. When Pin had already
-- paid the business for that booking, it takes the business's share back from the
-- business's next payout.

alter table bookings
    add column cancelled_at         timestamptz,
    add column cancelled_by         uuid references staff_members (id),
    -- Kept as written at the time, like checked_in_by_name.
    add column cancelled_by_name    text,
    add column cancel_reason        text
        check (cancel_reason in ('buyerAsked', 'eventChanged', 'soldByMistake', 'other')),
    -- The payout that took back the refund of a booking Pin had already paid out.
    add column refund_recovered_by  uuid references payouts (id);

-- All four are set together, on cancelled bookings only. Bookings cancelled before
-- cancellations were recorded have none of them.
alter table bookings add constraint bookings_cancellation check (
    (cancelled_at is null and cancelled_by is null and cancelled_by_name is null and cancel_reason is null)
    or (status = 'cancelled' and cancelled_at is not null and cancelled_by is not null
        and cancelled_by_name is not null and cancel_reason is not null));

-- Only a paid-out booking that was cancelled since has a refund to take back.
alter table bookings add constraint bookings_refund_recovered check (
    refund_recovered_by is null or (status = 'cancelled' and payout_id is not null));

-- Finds the refunds still to take back.
create index bookings_refunds_to_recover on bookings (event_id)
    where status = 'cancelled' and payout_id is not null and refund_recovered_by is null;

-- What a payout took back for refunds; payouts so far took back nothing.
alter table payouts add column refunds_cents bigint not null default 0 check (refunds_cents >= 0);
alter table payouts drop constraint payouts_check;
alter table payouts add constraint payouts_net check (net_cents = gross_cents - commission_cents - refunds_cents);
