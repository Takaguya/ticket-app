package com.ticket.app.backend.booking.domain;

/**
 * The five answers to scanning a ticket or typing its booking ID. Only
 * {@link Admitted} lets guests in.
 */
public sealed interface CheckInResult {

    /** Valid and not used before. The whole booking is now checked in. */
    record Admitted(Booking booking) implements CheckInResult {
    }

    /** Scanned before. The booking carries the first scan's time and staff name. */
    record AlreadyUsed(Booking booking) implements CheckInResult {
    }

    /** The buyer cancelled it. */
    record Cancelled(Booking booking) implements CheckInResult {
    }

    /**
     * A real ticket for a different event. The buyer and tickets are only given when
     * that event is the same business's; another business's customers stay private.
     */
    record OtherEvent(BookingId bookingId, String eventName, String buyerName, String summary)
            implements CheckInResult {
    }

    /** No booking with this ID. {@code code} is what was scanned or typed, tidied up. */
    record NotFound(String code) implements CheckInResult {
    }
}
