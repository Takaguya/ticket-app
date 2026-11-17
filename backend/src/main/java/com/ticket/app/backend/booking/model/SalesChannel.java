package com.ticket.app.backend.booking.model;

import java.util.Arrays;

/** Where a booking was sold. Door sales exist only on the merchant side and carry no commission. */
public enum SalesChannel {
    ONLINE("online", "Online"),
    DOOR("door", "At the door");

    private final String code;
    private final String label;

    SalesChannel(String code, String label) {
        this.code = code;
        this.label = label;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    public String label() {
        return label;
    }

    public static SalesChannel fromCode(String code) {
        return Arrays.stream(values())
                .filter(channel -> channel.code.equals(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown sales channel: " + code));
    }
}
