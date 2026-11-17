package com.ticket.app.backend.booking.dto;

import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.booking.service.PlaceCatalogService.Left;

/** What is left on one day; {@code left} is null for a ticket type with no limit. */
public record AvailabilityResponse(LocalDate date, List<LeftResponse> ticketTypes) {

    public static AvailabilityResponse of(LocalDate date, List<Left> left) {
        return new AvailabilityResponse(date, left.stream()
                .map(item -> new LeftResponse(item.ticketType(), item.left()))
                .toList());
    }
}
