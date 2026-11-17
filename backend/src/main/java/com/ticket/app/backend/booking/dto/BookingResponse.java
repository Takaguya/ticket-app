package com.ticket.app.backend.booking.dto;

import static com.ticket.app.backend.booking.dto.WebTimes.local;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.SeatBooking;

/**
 * A booking as the merchant app sees it, matching its Booking. Enum values use the app's names
 * ({@code abaKhqr}, {@code checkedIn}, ...). Times are local to Pin's time zone, without an offset.
 *
 * <p>{@code totalCents} is the tickets' full price, which the business is paid on: Pin pays
 * for promo codes, so it is more than the buyer paid when {@code promoCode} is set.
 * {@code promoCode} is null when none was used. {@code runner}, for a race booked in the
 * Pin app, is visible to the whole team: {@code {name, phone, email, gender, age,
 * nationality, emergencyName, emergencyPhone, shirtSize}}; null for any other booking.
 */
public record BookingResponse(String id, String eventId, String buyerName, String phone, List<LineJson> lines,
                       long totalCents, String promoCode, String payment, String channel, String status,
                       List<String> tshirtSizes, CheckInResponse checkIn, CancellationResponse cancellation,
                       RunnerJson runner, List<String> seats, LocalDate visitDate,
                       LocalDateTime createdAt) {

    /**
     * {@code seats}: the seat ids of a bus trip or screening, e.g. {@code 3A}; empty for any other
     * event. {@code visitDate}: the day a place's tickets are for; null for any other event.
     */
    public static BookingResponse of(Booking booking, ZoneId zone) {
        return new BookingResponse(
                booking.id().value(),
                booking.eventId().toString(),
                booking.buyerName(),
                booking.phone().value(),
                booking.lines().stream().map(LineJson::of).toList(),
                booking.subtotal().cents(),
                booking.purchase() == null ? null : booking.purchase().promoCode(),
                booking.payment().code(),
                booking.channel().code(),
                booking.status().code(),
                booking.tshirtSizes(),
                CheckInResponse.of(booking.checkIn(), zone),
                CancellationResponse.of(booking, zone),
                booking.purchase() == null ? null : RunnerJson.of(booking.purchase().runner()),
                booking.seats().stream().map(SeatBooking::seatId).toList(),
                booking.visitDate(),
                local(booking.createdAt(), zone));
    }
}
