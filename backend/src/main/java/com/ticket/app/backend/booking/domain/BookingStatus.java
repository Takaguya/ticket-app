package com.ticket.app.backend.booking.domain;

import java.util.Arrays;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * Where a booking is in its life. The user app's "Confirmed" ticket is {@link #OPEN}
 * here, and its "Used" ticket is {@link #CHECKED_IN}.
 */
public enum BookingStatus {
    OPEN("open", "Not checked in"),
    CHECKED_IN("checkedIn", "Checked in"),
    CANCELLED("cancelled", "Cancelled");

    private final String code;
    private final String label;

    BookingStatus(String code, String label) {
        this.code = code;
        this.label = label;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    /** As the merchant sees it. */
    public String label() {
        return label;
    }

    public static BookingStatus fromCode(String code) {
        return Arrays.stream(values())
                .filter(status -> status.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Unknown booking status: " + code));
    }
}
