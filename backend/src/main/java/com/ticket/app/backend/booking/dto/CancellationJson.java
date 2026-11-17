package com.ticket.app.backend.booking.dto;

import static com.ticket.app.backend.booking.dto.WebTimes.local;

import java.time.LocalDateTime;
import java.time.ZoneId;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.Cancellation;

/**
 * Null unless the business cancelled the booking. {@code reason}: buyerAsked,
 * eventChanged, soldByMistake or other. {@code refundCents}: what Pin pays back to the
 * buyer, everything they paid.
 */
public record CancellationJson(LocalDateTime at, String reason, String businessName, long refundCents) {

    public static CancellationJson of(Booking booking, String businessName, ZoneId zone) {
        Cancellation cancellation = booking.cancellation();
        return cancellation == null ? null : new CancellationJson(local(cancellation.at(), zone),
                cancellation.reason().code(), businessName, booking.refund().cents());
    }
}
