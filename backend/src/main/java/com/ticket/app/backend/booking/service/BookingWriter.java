package com.ticket.app.backend.booking.service;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.repository.BookingRepository;
import org.springframework.stereotype.Component;

/**
 * Saves a {@link PreparedSale} under a booking ID nobody has yet. IDs are drawn at random, so two
 * bookings can meet on one: the sale is then booked again under another ID.
 */
@Component
class BookingWriter {

    private static final int ID_DRAWS = 20;

    private final BookingRepository bookings;

    BookingWriter(BookingRepository bookings) {
        this.bookings = bookings;
    }

    /** Saves the sale as a new booking. The caller holds the event, so its limits stay true. */
    Booking add(PreparedSale sale) {
        for (int draw = 0; draw < ID_DRAWS; draw++) {
            Booking booking = sale.book(BookingId.random());
            if (bookings.tryAdd(booking)) {
                sale.saved(booking);
                return booking;
            }
            // Another booking has that ID: draw another.
        }
        throw new IllegalStateException("Could not find a free booking ID");
    }
}
