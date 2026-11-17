package com.ticket.app.backend.booking.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * {@code attemptId}: a UUID the app makes for each scan and sends again when it
 * retries after a lost answer. Optional.
 */
public record CheckInRequest(
        @NotBlank(message = "Choose the event to check in for.") String eventId,
        @NotBlank(message = "Scan the ticket or type its booking ID.") String code,
        String attemptId) {
}
