package com.ticket.app.backend.business.domain;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.domain.Ids;
import com.ticket.app.backend.shared.domain.NotFoundException;

public record StaffId(UUID value) {

    public StaffId {
        Objects.requireNonNull(value, "value");
    }

    public static StaffId newId() {
        return new StaffId(Ids.newId());
    }

    /** An ID from a URL. Anything that is not one cannot name a team member. */
    public static StaffId parse(String text) {
        try {
            return new StaffId(UUID.fromString(text));
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new NotFoundException("This person is not on the team.");
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
