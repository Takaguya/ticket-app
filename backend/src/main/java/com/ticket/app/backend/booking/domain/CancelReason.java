package com.ticket.app.backend.booking.domain;

import java.util.Arrays;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/** Why the business cancelled a booking. The buyer is shown it on their ticket. */
public enum CancelReason {
    BUYER_ASKED("buyerAsked", "The buyer asked to cancel"),
    EVENT_CHANGED("eventChanged", "The event changed or was called off"),
    SOLD_BY_MISTAKE("soldByMistake", "Sold by mistake"),
    OTHER("other", "Other reason");

    private final String code;
    private final String label;

    CancelReason(String code, String label) {
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

    public static CancelReason fromCode(String code) {
        return Arrays.stream(values())
                .filter(reason -> reason.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose why the booking is cancelled."));
    }
}
