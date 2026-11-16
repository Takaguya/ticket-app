-- What kind of event it is: the merchant chooses when publishing. It replaces the hidden
-- event_pages.needs_runner_details flag: a marathon asks the buyer for the runner's
-- details, the other kinds go straight to checkout. Existing events default to a concert,
-- except those whose page asked for runner details, which were marathons.
alter table events
    add column kind text not null default 'concert' check (kind in ('marathon', 'concert', 'show'));

update events
set kind = 'marathon'
where id in (select event_id from event_pages where needs_runner_details);

alter table event_pages drop column needs_runner_details;
