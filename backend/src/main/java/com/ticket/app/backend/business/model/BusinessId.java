package com.ticket.app.backend.business.model;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.model.Ids;
import com.ticket.app.backend.shared.model.NotFoundException;

public record BusinessId(UUID value) {

    public BusinessId {
        Objects.requireNonNull(value, "value");
    }

    public static BusinessId newId() {
        return new BusinessId(Ids.newId());
    }

    /** An ID from a URL or request. Anything that is not one cannot name a business. */
    public static BusinessId parse(String text) {
        try {
            return new BusinessId(UUID.fromString(text));
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new NotFoundException("This business does not exist.");
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
