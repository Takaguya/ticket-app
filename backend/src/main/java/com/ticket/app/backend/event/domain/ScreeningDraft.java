package com.ticket.app.backend.event.domain;

import java.time.LocalDateTime;

import com.ticket.app.backend.shared.domain.Money;

/**
 * What the owner of a cinema fills in to publish a screening. It becomes an event (the cinema
 * is its venue) plus the {@link Screening}.
 *
 * @param startsAt     when the film starts, local time
 * @param price        per seat
 * @param theatre      the cinema or branch, e.g. "Legend Cinema, Aeon Mall"
 * @param theatreArea  where it is; may be empty
 * @param about        the film's synopsis; may be empty
 */
public record ScreeningDraft(String filmTitle, String rating, String genre, int runtimeMinutes, String about,
                             String theatre, String theatreArea, String hall, SeatLayout layout,
                             LocalDateTime startsAt, Money price) {
}
