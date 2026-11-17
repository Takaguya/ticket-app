package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.model.BookingLine;

/** How many tickets of one type a booking holds, or a door sale asks for. */
public record LineJson(String ticketType, int quantity) {

    public static LineJson of(BookingLine line) {
        return new LineJson(line.ticketType(), line.quantity());
    }

    public BookingLine toLine() {
        return new BookingLine(ticketType, quantity);
    }
}
