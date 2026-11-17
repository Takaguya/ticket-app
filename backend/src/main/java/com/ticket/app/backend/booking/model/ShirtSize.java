package com.ticket.app.backend.booking.model;

import java.util.Arrays;

import com.ticket.app.backend.shared.model.BusinessRuleException;

/** Race kit T-shirt sizes. */
public enum ShirtSize {
    XS("XS"),
    S("S"),
    M("M"),
    L("L"),
    XL("XL");

    private final String code;

    ShirtSize(String code) {
        this.code = code;
    }

    /** The size as printed, e.g. {@code XL}; also used in the API and the database. */
    public String code() {
        return code;
    }

    public static ShirtSize fromCode(String code) {
        return Arrays.stream(values())
                .filter(size -> size.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose a T-shirt size."));
    }
}
