package com.ticket.app.backend.buyer.model;

import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.shared.model.Ids;
import com.ticket.app.backend.shared.model.NotFoundException;

public record BuyerId(UUID value) {

    public BuyerId {
        Objects.requireNonNull(value, "value");
    }

    public static BuyerId newId() {
        return new BuyerId(Ids.newId());
    }

    /** An ID from a URL. Anything that is not one cannot name a buyer. */
    public static BuyerId parse(String text) {
        try {
            return new BuyerId(UUID.fromString(text));
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new NotFoundException("This account does not exist.");
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
