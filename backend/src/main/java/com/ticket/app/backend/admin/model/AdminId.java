package com.ticket.app.backend.admin.model;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.model.NotFoundException;

public record AdminId(UUID value) {

    public AdminId {
        Objects.requireNonNull(value, "value");
    }

    /** An ID from a URL. Anything that is not one is an admin that does not exist. */
    public static AdminId parse(String text) {
        try {
            return new AdminId(UUID.fromString(text));
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new NotFoundException("This admin does not exist.");
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
