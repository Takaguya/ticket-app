package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.event.model.Screening;

/**
 * What a booked screening adds to the event as a buyer sees it: the film (its name is the
 * event's), where it shows and how big the hall is. {@code hallSize} is small, standard or large.
 */
public record ScreeningJson(String filmId, String rating, String genre, int runtimeMinutes, String hall,
                     String hallSize, String hallLabel) {

    /** Null for an event that is not a screening. */
    public static ScreeningJson of(Screening screening) {
        return screening == null ? null : new ScreeningJson(screening.filmId(), screening.rating(),
                screening.genre(), screening.runtimeMinutes(), screening.hall(), screening.layout().code(),
                screening.layout().label());
    }
}
