package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.event.model.Event;

/** {@code unitPriceCents} is the ticket type's price, which an event keeps after publishing. */
public record BookedLine(String ticketType, int quantity, long unitPriceCents) {

    public static BookedLine of(BookingLine line, Event event) {
        long unitPrice = event.ticketType(line.ticketType()).map(type -> type.price().cents()).orElse(0L);
        return new BookedLine(line.ticketType(), line.quantity(), unitPrice);
    }
}
