package com.ticket.app.backend.event.dto;

import java.time.LocalDateTime;

import com.ticket.app.backend.event.model.ScreeningDraft;
import com.ticket.app.backend.event.model.SeatLayout;
import com.ticket.app.backend.shared.model.Money;
import jakarta.validation.constraints.NotNull;

/**
 * What the owner of a cinema fills in to publish a screening. {@code startsAt} is when the film
 * starts; {@code hallSize} is small, standard or large; {@code priceCents} is per seat. {@code
 * rating}, {@code genre}, {@code about} and {@code theatreArea} are optional. {@code theatre} is
 * the cinema or branch the buyers see, e.g. "Legend Cinema, Aeon Mall".
 */
public record PublishScreeningRequest(
        String filmTitle,
        String rating,
        String genre,
        Integer runtimeMinutes,
        String about,
        String theatre,
        String theatreArea,
        String hall,
        String hallSize,
        LocalDateTime startsAt,
        @NotNull(message = "Enter the price of a seat (0 for free).") Long priceCents) {

    public ScreeningDraft toDraft() {
        return new ScreeningDraft(filmTitle, rating, genre, runtimeMinutes == null ? 0 : runtimeMinutes, about,
                theatre, theatreArea, hall, SeatLayout.hallFromCode(hallSize), startsAt, Money.ofCents(priceCents));
    }
}
