package com.ticket.app.backend.booking.model;

import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;

import com.ticket.app.backend.shared.model.Secrets;

/** {@code TK} followed by 8 digits, e.g. {@code TK48213377}. Printed on the ticket and in its QR code. */
public record BookingId(String value) {

    private static final Pattern FORMAT = Pattern.compile("TK[0-9]{8}");
    private static final Pattern EIGHT_DIGITS = Pattern.compile("[0-9]{8}");

    public BookingId {
        if (value == null || !FORMAT.matcher(value).matches()) {
            throw new IllegalArgumentException("A booking ID is TK and 8 digits");
        }
    }

    /**
     * What was scanned or typed: {@code TK48213377}, {@code tk48213377}, or the 8 digits
     * alone. Empty when it cannot be a booking ID.
     */
    public static Optional<BookingId> parse(String code) {
        if (code == null) {
            return Optional.empty();
        }
        String text = code.strip().toUpperCase(Locale.ROOT);
        if (EIGHT_DIGITS.matcher(text).matches()) {
            text = "TK" + text;
        }
        return FORMAT.matcher(text).matches() ? Optional.of(new BookingId(text)) : Optional.empty();
    }

    /** A new random ID. Another booking may already have it, so saving must check. */
    public static BookingId random() {
        return new BookingId("TK" + (10_000_000 + Secrets.below(90_000_000)));
    }

    @Override
    public String toString() {
        return value;
    }
}
