package com.ticket.app.backend.event.domain;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.domain.Ids;
import com.ticket.app.backend.shared.domain.NotFoundException;

public record EventId(UUID value) {

    public EventId {
        Objects.requireNonNull(value, "value");
    }

    public static EventId newId() {
        return new EventId(Ids.newId());
    }

    /** An ID from a URL or request. Anything that is not one cannot name an event. */
    public static EventId parse(String text) {
        try {
            return new EventId(UUID.fromString(text));
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new NotFoundException("This event does not exist.");
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
