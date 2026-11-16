package com.ticket.app.backend.booking.domain;

import java.util.Arrays;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/** How a booking was paid. The user app's ABA Pay counts as ABA / KHQR. */
public enum PaymentMethod {
    ABA_KHQR("abaKhqr", "ABA / KHQR"),
    CARD("card", "Card"),
    CASH("cash", "Cash");

    private final String code;
    private final String label;

    PaymentMethod(String code, String label) {
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

    /** At the door a buyer pays cash or by KHQR. */
    public boolean isAcceptedAtDoor() {
        return this == CASH || this == ABA_KHQR;
    }

    public static PaymentMethod fromCode(String code) {
        return Arrays.stream(values())
                .filter(method -> method.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose how the buyer pays."));
    }
}
