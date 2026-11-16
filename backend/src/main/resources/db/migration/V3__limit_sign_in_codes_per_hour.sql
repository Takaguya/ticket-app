-- Count the sign-in codes sent to a number within the current hour, so only a few
-- can be sent per hour. Each code allows a few guesses; without this limit someone
-- could ask for a new code every 30 seconds and keep guessing.
alter table otp_challenges
    add column sends_in_window int not null default 1,
    add column window_started_at timestamptz;

update otp_challenges set window_started_at = sent_at;

alter table otp_challenges alter column window_started_at set not null;
