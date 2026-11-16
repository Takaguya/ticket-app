package com.ticket.app.backend.buyer.domain;

import java.util.Arrays;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/** The gender a buyer, or a runner, gives. */
public enum Gender {
    FEMALE("female"),
    MALE("male"),
    OTHER("other");

    private final String code;

    Gender(String code) {
        this.code = code;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    public static Gender fromCode(String code) {
        return Arrays.stream(values())
                .filter(gender -> gender.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose your gender."));
    }
}
