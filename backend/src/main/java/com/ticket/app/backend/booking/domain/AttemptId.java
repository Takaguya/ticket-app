package com.ticket.app.backend.booking.domain;

import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * Names one try at a check-in or a door sale. The app makes a new one for each new
 * scan or sale and sends the same one again when it retries after a lost answer,
 * so the server can tell a retry from a second scan.
 */
public record AttemptId(UUID value) {

    public AttemptId {
        Objects.requireNonNull(value, "value");
    }

    /** From a request. Empty when the app sent none; anything that is not a UUID is refused. */
    public static Optional<AttemptId> parseOptional(String text) {
        if (text == null || text.isBlank()) {
            return Optional.empty();
        }
        try {
            return Optional.of(new AttemptId(UUID.fromString(text.strip())));
        } catch (IllegalArgumentException e) {
            throw BusinessRuleException.invalid("The attempt ID is not valid.");
        }
    }
}
