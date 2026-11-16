package com.ticket.app.backend.booking.application;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;

/**
 * A sale checked and priced, waiting for a free booking ID. {@link SalesRules} read what they need
 * (what is sold so far, which seats are held) while the event is locked, and hand back one of
 * these; {@link BookingWriter} gives it an ID and saves it.
 */
@FunctionalInterface
interface PreparedSale {

    /**
     * The booking with this ID. Refuses (a {@code BusinessRuleException}) a sale that breaks a rule,
     * such as too many tickets or a seat that is taken.
     */
    Booking book(BookingId id);

    /** Runs once the booking is saved: e.g. keeping a runner for the buyer's next race. */
    default void saved(Booking booking) {
    }
}
