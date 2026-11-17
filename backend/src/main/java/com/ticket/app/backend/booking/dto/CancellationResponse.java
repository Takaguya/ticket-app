package com.ticket.app.backend.booking.dto;

import static com.ticket.app.backend.booking.dto.WebTimes.local;

import java.time.LocalDateTime;
import java.time.ZoneId;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.Cancellation;

/**
 * Null unless the business cancelled the booking (bookings cancelled before this was
 * recorded have none). {@code reason}: buyerAsked, eventChanged, soldByMistake or
 * other. {@code refundCents}: what Pin paid back to the buyer, everything for an
 * online booking; 0 for a door sale, which the business pays back itself.
 */
public record CancellationResponse(LocalDateTime at, String staffName, String reason, long refundCents) {

    public static CancellationResponse of(Booking booking, ZoneId zone) {
        Cancellation cancellation = booking.cancellation();
        return cancellation == null ? null : new CancellationResponse(local(cancellation.at(), zone),
                cancellation.staffName(), cancellation.reason().code(), booking.refund().cents());
    }
}
