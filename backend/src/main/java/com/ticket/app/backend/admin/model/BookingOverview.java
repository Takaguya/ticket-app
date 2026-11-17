package com.ticket.app.backend.admin.model;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.booking.model.SalesChannel;
import com.ticket.app.backend.shared.model.Money;

/** One booking as the back office lists it, with its event and business. */
public record BookingOverview(BookingId id, String buyerName, String eventName, String merchantName, int tickets,
                              Money total, PaymentMethod payment, SalesChannel channel, BookingStatus status,
                              Instant createdAt) {

    /**
     * One page of a search: the bookings on it, how many match in all, which page this
     * is (from 1) and how many bookings a page holds.
     */
    public record Page(List<BookingOverview> bookings, int total, int number, int size) {

        public Page {
            bookings = List.copyOf(bookings);
        }

        /** How many pages the matches fill; at least 1, an empty first page. */
        public int pages() {
            return Math.max(1, (total + size - 1) / size);
        }
    }

    public BookingOverview {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(buyerName, "buyerName");
        Objects.requireNonNull(eventName, "eventName");
        Objects.requireNonNull(merchantName, "merchantName");
        Objects.requireNonNull(total, "total");
        Objects.requireNonNull(payment, "payment");
        Objects.requireNonNull(channel, "channel");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(createdAt, "createdAt");
    }
}
