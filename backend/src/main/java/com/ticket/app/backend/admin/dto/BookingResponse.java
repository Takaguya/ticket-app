package com.ticket.app.backend.admin.dto;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

import com.ticket.app.backend.admin.model.BookingOverview;

/** One booking in the admin panel's list. */
public record BookingResponse(String id, String buyerName, String eventName, String merchantName, int tickets,
                       long totalCents, String payment, String channel, String status, LocalDateTime createdAt) {

    public static BookingResponse of(BookingOverview booking, ZoneId zone) {
        return new BookingResponse(booking.id().value(), booking.buyerName(), booking.eventName(),
                booking.merchantName(), booking.tickets(), booking.total().cents(), booking.payment().code(),
                booking.channel().code(), booking.status().code(),
                LocalDateTime.ofInstant(booking.createdAt(), zone).truncatedTo(ChronoUnit.SECONDS));
    }
}
