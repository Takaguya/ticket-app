package com.ticket.app.backend.booking.dto;

import java.time.ZoneId;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.CheckInResult;

/**
 * What a scan found, matching the merchant app's CheckInResult. {@code result} is admitted,
 * alreadyUsed, cancelled, otherEvent or notFound.
 * The first three carry the booking; otherEvent carries bookingId and eventName,
 * and buyerName and summary for the business's own events; notFound carries bookingId.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record CheckInResultResponse(String result, BookingResponse booking, String bookingId, String eventName,
                             String buyerName, String summary) {

    public static CheckInResultResponse of(CheckInResult result, ZoneId zone) {
        return switch (result) {
            case CheckInResult.Admitted r -> withBooking("admitted", r.booking(), zone);
            case CheckInResult.AlreadyUsed r -> withBooking("alreadyUsed", r.booking(), zone);
            case CheckInResult.Cancelled r -> withBooking("cancelled", r.booking(), zone);
            case CheckInResult.OtherEvent r -> new CheckInResultResponse("otherEvent", null,
                    r.bookingId().value(), r.eventName(), r.buyerName(), r.summary());
            case CheckInResult.NotFound r -> new CheckInResultResponse("notFound", null, r.code(),
                    null, null, null);
        };
    }

    private static CheckInResultResponse withBooking(String result, Booking booking, ZoneId zone) {
        return new CheckInResultResponse(result, BookingResponse.of(booking, zone), booking.id().value(),
                null, null, null);
    }
}
