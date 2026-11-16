package com.ticket.app.backend.booking.web;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.ticket.app.backend.booking.application.DoorSale;
import com.ticket.app.backend.booking.domain.AttemptId;
import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.CancelReason;
import com.ticket.app.backend.booking.domain.Cancellation;
import com.ticket.app.backend.booking.domain.CheckIn;
import com.ticket.app.backend.booking.domain.CheckInResult;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.booking.domain.SeatBooking;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * JSON of the booking endpoints, matching the merchant app's Booking, CheckInResult
 * and SalesSummary. Enum values use the app's names ({@code abaKhqr},
 * {@code checkedIn}, ...). Times are local to Pin's time zone, without an offset.
 */
final class BookingDtos {

    private BookingDtos() {
    }

    record LineJson(String ticketType, int quantity) {

        static LineJson of(BookingLine line) {
            return new LineJson(line.ticketType(), line.quantity());
        }

        BookingLine toLine() {
            return new BookingLine(ticketType, quantity);
        }
    }

    /**
     * {@code totalCents} is the tickets' full price, which the business is paid on: Pin pays
     * for promo codes, so it is more than the buyer paid when {@code promoCode} is set.
     * {@code promoCode} is null when none was used. {@code runner}, for a race booked in the
     * Pin app, is visible to the whole team: {@code {name, phone, email, gender, age,
     * nationality, emergencyName, emergencyPhone, shirtSize}}; null for any other booking.
     */
    record BookingResponse(String id, String eventId, String buyerName, String phone, List<LineJson> lines,
                           long totalCents, String promoCode, String payment, String channel, String status,
                           List<String> tshirtSizes, CheckInResponse checkIn, CancellationResponse cancellation,
                           BuyerBookingDtos.RunnerJson runner, List<String> seats, LocalDate visitDate,
                           LocalDateTime createdAt) {

        /**
         * {@code seats}: the seat ids of a bus trip or screening, e.g. {@code 3A}; empty for any other
         * event. {@code visitDate}: the day a place's tickets are for; null for any other event.
         */
        static BookingResponse of(Booking booking, ZoneId zone) {
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
                    booking.purchase() == null ? null : BuyerBookingDtos.RunnerJson.of(booking.purchase().runner()),
                    booking.seats().stream().map(SeatBooking::seatId).toList(),
                    booking.visitDate(),
                    local(booking.createdAt(), zone));
        }
    }

    /** Null when the booking is not checked in. */
    record CheckInResponse(LocalDateTime at, String staffName) {

        static CheckInResponse of(CheckIn checkIn, ZoneId zone) {
            return checkIn == null ? null : new CheckInResponse(local(checkIn.at(), zone), checkIn.staffName());
        }
    }

    /**
     * Null unless the business cancelled the booking (bookings cancelled before this was
     * recorded have none). {@code reason}: buyerAsked, eventChanged, soldByMistake or
     * other. {@code refundCents}: what Pin paid back to the buyer, everything for an
     * online booking; 0 for a door sale, which the business pays back itself.
     */
    record CancellationResponse(LocalDateTime at, String staffName, String reason, long refundCents) {

        static CancellationResponse of(Booking booking, ZoneId zone) {
            Cancellation cancellation = booking.cancellation();
            return cancellation == null ? null : new CancellationResponse(local(cancellation.at(), zone),
                    cancellation.staffName(), cancellation.reason().code(), booking.refund().cents());
        }
    }

    /** {@code reason}: buyerAsked, eventChanged, soldByMistake or other. */
    record CancelRequest(@NotBlank(message = "Choose why the booking is cancelled.") String reason) {

        CancelReason toReason() {
            return CancelReason.fromCode(reason);
        }
    }

    /**
     * {@code attemptId}: a UUID the app makes for each scan and sends again when it
     * retries after a lost answer. Optional.
     */
    record CheckInRequest(
            @NotBlank(message = "Choose the event to check in for.") String eventId,
            @NotBlank(message = "Scan the ticket or type its booking ID.") String code,
            String attemptId) {
    }

    /**
     * {@code result} is admitted, alreadyUsed, cancelled, otherEvent or notFound.
     * The first three carry the booking; otherEvent carries bookingId and eventName,
     * and buyerName and summary for the business's own events; notFound carries bookingId.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    record CheckInResultResponse(String result, BookingResponse booking, String bookingId, String eventName,
                                 String buyerName, String summary) {

        static CheckInResultResponse of(CheckInResult result, ZoneId zone) {
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

    /** {@code attemptId}: a UUID for this sale, sent again on retries. Optional. */
    record DoorSaleRequest(
            @NotNull(message = "Choose at least one ticket.") List<@NotNull(message = "Choose at least one ticket.") @Valid LineJson> lines,
            @NotBlank(message = "Enter the buyer's phone number.") String buyerPhone,
            @NotBlank(message = "Choose how the buyer pays.") String payment,
            String attemptId) {

        DoorSale toDoorSale() {
            return new DoorSale(lines.stream().map(LineJson::toLine).toList(), PhoneNumber.of(buyerPhone),
                    PaymentMethod.fromCode(payment), AttemptId.parseOptional(attemptId).orElse(null));
        }
    }

    record SummaryResponse(int capacity, int sold, int left, int checkedIn, int bookingCount, long onlineCents,
                           long doorCents, long revenueCents, long commissionCents, double commissionRate,
                           long netCents, List<TicketTypeSalesResponse> byTicketType) {

        static SummaryResponse of(SalesSummary summary) {
            return new SummaryResponse(summary.capacity(), summary.sold(), summary.left(), summary.checkedIn(),
                    summary.bookingCount(), summary.online().cents(), summary.door().cents(),
                    summary.revenue().cents(), summary.commission().cents(), summary.commissionRate().doubleValue(),
                    summary.net().cents(),
                    summary.byTicketType().stream().map(TicketTypeSalesResponse::of).toList());
        }
    }

    record TicketTypeSalesResponse(String name, int quantity, int sold, int checkedIn, int left) {

        static TicketTypeSalesResponse of(SalesSummary.TicketTypeSales sales) {
            return new TicketTypeSalesResponse(sales.name(), sales.quantity(), sales.sold(), sales.checkedIn(),
                    sales.left());
        }
    }

    /** Whole seconds: the database keeps microseconds, so finer times would differ once saved. */
    private static LocalDateTime local(Instant instant, ZoneId zone) {
        return LocalDateTime.ofInstant(instant, zone).truncatedTo(ChronoUnit.SECONDS);
    }
}
