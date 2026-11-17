package com.ticket.app.backend.admin.dto;

import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.admin.model.BookingOverview;

/** {@code total}: how many bookings match in all; {@code bookings} holds the newest of them. */
public record BookingsResponse(int total, int page, int size, int pages, List<BookingResponse> bookings) {

    public static BookingsResponse of(BookingOverview.Page page, ZoneId zone) {
        return new BookingsResponse(page.total(), page.number(), page.size(), page.pages(),
                page.bookings().stream().map(booking -> BookingResponse.of(booking, zone)).toList());
    }
}
