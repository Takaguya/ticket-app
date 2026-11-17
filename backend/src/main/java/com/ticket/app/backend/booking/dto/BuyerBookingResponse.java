package com.ticket.app.backend.booking.dto;

import static com.ticket.app.backend.booking.dto.WebTimes.local;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.booking.service.BuyerBooking;
import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.OnlinePurchase;
import com.ticket.app.backend.booking.model.SeatBooking;
import com.ticket.app.backend.event.service.EventOnSale;

/**
 * A booking as the buyer sees it, matching the user app's Booking. Enum values use the API's names
 * ({@code abaKhqr}, {@code card}, {@code female}, {@code XL}, ...). Times are local to Pin's time zone,
 * without an offset. Money is whole US cents.
 *
 * <p>{@code status}: open, checkedIn or cancelled. {@code holderName} is the runner's name
 * for a race, else the buyer's. {@code promoCode} and {@code runner} are null when the
 * booking has none; {@code cancellation} is null unless the business cancelled it.
 * {@code seats} are the seat ids of a bus trip or a screening, e.g. {@code 3A}; empty for any
 * other event. {@code visitDate} is the day a place's tickets are good for; null otherwise.
 */
public record BuyerBookingResponse(String id, String status, String holderName, String payment, String promoCode,
                            long discountCents, long subtotalCents, long totalCents, LocalDateTime bookedAt,
                            List<BookedLine> lines, List<String> seats, LocalDate visitDate, EventJson event,
                            RunnerJson runner, CancellationJson cancellation) {

    public static BuyerBookingResponse of(BuyerBooking item, ZoneId zone) {
        Booking booking = item.booking();
        EventOnSale listing = item.event();
        OnlinePurchase purchase = booking.purchase();
        return new BuyerBookingResponse(
                booking.id().value(),
                booking.status().code(),
                booking.buyerName(),
                booking.payment().code(),
                purchase == null ? null : purchase.promoCode(),
                booking.discount().cents(),
                booking.subtotal().cents(),
                booking.total().cents(),
                local(booking.createdAt(), zone),
                booking.lines().stream().map(line -> BookedLine.of(line, listing.event())).toList(),
                booking.seats().stream().map(SeatBooking::seatId).toList(),
                booking.visitDate(),
                EventJson.of(listing),
                purchase == null ? null : RunnerJson.of(purchase.runner()),
                CancellationJson.of(booking, listing.organiser(), zone));
    }
}
