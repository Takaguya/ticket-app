package com.ticket.app.backend.shared.domain;

import java.util.regex.Pattern;

/**
 * A Cambodian phone number in E.164 form, e.g. {@code +85512345678}: +855 and the 8
 * or 9 national digits without the leading 0. Always valid once made.
 *
 * <p>Pin works in Cambodia only. Refusing other countries also means sign-in codes
 * cannot be sent to costly foreign numbers.
 */
public record PhoneNumber(String value) {

    private static final Pattern CAMBODIA = Pattern.compile("\\+855[1-9][0-9]{7,8}");

    public PhoneNumber {
        if (value == null || !CAMBODIA.matcher(value).matches()) {
            throw BusinessRuleException.invalid("Enter a valid phone number.");
        }
    }

    public static PhoneNumber of(String value) {
        return new PhoneNumber(value == null ? null : value.strip());
    }

    /** The digits only, without the plus sign. */
    public String digits() {
        return value.substring(1);
    }

    /** The digits as dialled inside Cambodia, with a leading 0 instead of +855, e.g. {@code 012345678}. */
    public String localDigits() {
        return "0" + value.substring(4);
    }

    @Override
    public String toString() {
        return value;
    }
}
