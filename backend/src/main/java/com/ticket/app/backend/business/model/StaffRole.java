package com.ticket.app.backend.business.model;

import java.util.Arrays;

/**
 * An owner can do everything. A scanner can only scan tickets and see bookings.
 */
public enum StaffRole {
    OWNER("owner"),
    SCANNER("scanner");

    private final String code;

    StaffRole(String code) {
        this.code = code;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    public static StaffRole fromCode(String code) {
        return Arrays.stream(values())
                .filter(role -> role.code.equals(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown role: " + code));
    }
}
