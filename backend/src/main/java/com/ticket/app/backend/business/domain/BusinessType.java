package com.ticket.app.backend.business.domain;

import java.util.Arrays;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/** What a business sells, chosen when it registers. */
public enum BusinessType {
    EVENTS("events"),
    BUS("bus"),
    CINEMA("cinema"),
    ADMISSION("admission");

    private final String code;

    BusinessType(String code) {
        this.code = code;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    public static BusinessType fromCode(String code) {
        return Arrays.stream(values())
                .filter(type -> type.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose what the business sells."));
    }
}
