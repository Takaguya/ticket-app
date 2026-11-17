package com.ticket.app.backend.business.model;

import java.util.Optional;
import java.util.regex.Pattern;

import com.ticket.app.backend.shared.model.Secrets;

/**
 * Six digits a new scanner types to join a business, shown as {@code 482 913}.
 * The owner can replace it; the old one then stops working.
 */
public record JoinCode(String digits) {

    private static final Pattern SIX_DIGITS = Pattern.compile("[0-9]{6}");

    public JoinCode {
        if (digits == null || !SIX_DIGITS.matcher(digits).matches()) {
            throw new IllegalArgumentException("A join code is six digits");
        }
    }

    /** What a person typed, e.g. {@code 482 913}. Empty when it is not six digits. */
    public static Optional<JoinCode> parse(String input) {
        if (input == null) {
            return Optional.empty();
        }
        String digits = input.replaceAll("\\D", "");
        return SIX_DIGITS.matcher(digits).matches() ? Optional.of(new JoinCode(digits)) : Optional.empty();
    }

    public static JoinCode random() {
        return new JoinCode(Secrets.digits(6));
    }

    @Override
    public String toString() {
        return digits;
    }
}
