package com.ticket.app.backend.business.model;

import java.util.Arrays;

/**
 * Where a business stands with Pin. A new business is {@link #PENDING} until an admin
 * approves it; an admin can suspend an active business and reinstate it.
 */
public enum BusinessStatus {
    /** Registered, waiting for an admin. Can set up events, cannot sell. */
    PENDING("pending"),
    /** Approved: sells tickets. */
    ACTIVE("active"),
    /** Stopped by an admin: cannot sell or publish; tickets already sold still scan. */
    SUSPENDED("suspended");

    private final String code;

    BusinessStatus(String code) {
        this.code = code;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    public static BusinessStatus fromCode(String code) {
        return Arrays.stream(values())
                .filter(status -> status.code.equals(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown business status: " + code));
    }
}
