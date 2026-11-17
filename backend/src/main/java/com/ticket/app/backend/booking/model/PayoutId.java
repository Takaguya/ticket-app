package com.ticket.app.backend.booking.model;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.model.Ids;

public record PayoutId(UUID value) {

    public PayoutId {
        Objects.requireNonNull(value, "value");
    }

    public static PayoutId newId() {
        return new PayoutId(Ids.newId());
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
