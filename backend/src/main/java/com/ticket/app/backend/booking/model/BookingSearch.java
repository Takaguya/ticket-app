package com.ticket.app.backend.booking.model;

import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * Searching an event's bookings, as on the Bookings screen.
 *
 * @param query  part of the buyer's name, part of the booking ID, or at least 3 digits
 *               of the phone number (spaces and punctuation ignored); empty matches all
 * @param status only bookings with this status, or null for all
 */
public record BookingSearch(String query, BookingStatus status) {

    public static final BookingSearch ALL = new BookingSearch("", null);

    public BookingSearch {
        query = query == null ? "" : query.strip().toLowerCase(Locale.ROOT);
    }

    public boolean matches(Booking booking) {
        if (status != null && booking.status() != status) {
            return false;
        }
        if (query.isEmpty()
                || booking.buyerName().toLowerCase(Locale.ROOT).contains(query)
                || booking.id().value().toLowerCase(Locale.ROOT).contains(query)) {
            return true;
        }
        String digits = query.replaceAll("\\D", "");
        return digits.length() >= 3
                && (booking.phone().digits().contains(digits) || booking.phone().localDigits().contains(digits));
    }

    /** The matching bookings, sorted by buyer name. */
    public List<Booking> apply(Collection<Booking> bookings) {
        return bookings.stream()
                .filter(this::matches)
                .sorted(Comparator.comparing(Booking::buyerName).thenComparing(b -> b.id().value()))
                .toList();
    }
}
