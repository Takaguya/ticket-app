package com.ticket.app.backend.event.dto;

import com.ticket.app.backend.event.model.Screening;

/** {@code hallSize}: small, standard or large; {@code hallLabel} reads like "Standard hall · 80 seats". */
public record ScreeningResponse(String filmTitle, String rating, String genre, int runtimeMinutes, String hall,
                         String hallSize, String hallLabel, int seats) {

    /** Null for an event that is not a screening. */
    public static ScreeningResponse of(Screening screening) {
        return screening == null ? null : new ScreeningResponse(screening.filmTitle(), screening.rating(),
                screening.genre(), screening.runtimeMinutes(), screening.hall(), screening.layout().code(),
                screening.layout().label(), screening.capacity());
    }
}
