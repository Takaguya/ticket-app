package com.ticket.app.backend.booking.domain;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * Tickets of one type on a booking, e.g. 2 × "10K".
 *
 * @param ticketType matches the name of one of the event's ticket types exactly
 */
public record BookingLine(String ticketType, int quantity) {

    public BookingLine {
        if (ticketType == null || ticketType.isBlank()) {
            throw BusinessRuleException.invalid("Choose a ticket type for every line.");
        }
        if (quantity < 1) {
            throw BusinessRuleException.invalid("Every line needs at least 1 ticket.");
        }
    }

    /** {@code 2× 10K} */
    @Override
    public String toString() {
        return quantity + "× " + ticketType;
    }
}
