package com.ticket.app.backend.shared.model;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * An email address in lower case, e.g. {@code moniroth@pin.example}, so it belongs to
 * one person however it is typed. Always valid once made.
 *
 * <p>Only the shape is checked (something, {@code @}, a domain with a dot): whether
 * the address works is only known by writing to it.
 */
public record EmailAddress(String value) {

    /** The longest address mail servers accept. */
    public static final int MAX_LENGTH = 254;

    private static final Pattern SHAPE = Pattern.compile("[^@\\s]+@[^@\\s]+\\.[^@\\s]+");

    public EmailAddress {
        if (value == null || value.length() > MAX_LENGTH || !SHAPE.matcher(value).matches()
                || !value.equals(value.toLowerCase(Locale.ROOT))) {
            throw BusinessRuleException.invalid("Enter a valid email address.");
        }
    }

    /** The address as typed: spaces around it are dropped and capitals made small. */
    public static EmailAddress of(String typed) {
        return new EmailAddress(typed == null ? null : typed.strip().toLowerCase(Locale.ROOT));
    }

    @Override
    public String toString() {
        return value;
    }
}
