package com.ticket.app.backend.event.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.event.model.BusTripDraft;
import com.ticket.app.backend.event.model.SeatLayout;
import com.ticket.app.backend.shared.model.Money;
import jakarta.validation.constraints.NotNull;

/**
 * What the owner of a bus company fills in to publish a trip. {@code startsAt} is when the
 * bus leaves; {@code coachType} is seater, vip or sleeper; {@code priceCents} is per seat.
 * {@code boardingAddress}, {@code about} and {@code amenities} are optional.
 */
public record PublishBusTripRequest(
        String origin,
        String destination,
        LocalDateTime startsAt,
        Integer durationMinutes,
        String coachType,
        @NotNull(message = "Enter the price of a seat (0 for free).") Long priceCents,
        String boardingPoint,
        String boardingAddress,
        String about,
        List<String> amenities) {

    public BusTripDraft toDraft() {
        return new BusTripDraft(origin, destination, startsAt, durationMinutes == null ? 0 : durationMinutes,
                SeatLayout.coachFromCode(coachType), Money.ofCents(priceCents), boardingPoint, boardingAddress,
                about, amenities);
    }
}
