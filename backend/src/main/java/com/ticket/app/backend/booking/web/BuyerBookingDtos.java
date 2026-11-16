package com.ticket.app.backend.booking.web;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.stream.IntStream;

import com.ticket.app.backend.booking.application.BuyerBooking;
import com.ticket.app.backend.booking.application.OnlineOrder;
import com.ticket.app.backend.booking.application.RunnerInput;
import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.Cancellation;
import com.ticket.app.backend.booking.domain.OnlinePurchase;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.booking.domain.Promotion;
import com.ticket.app.backend.booking.domain.Runner;
import com.ticket.app.backend.booking.domain.SeatBooking;
import com.ticket.app.backend.booking.web.BookingDtos.LineJson;
import com.ticket.app.backend.booking.web.BusCatalogDtos.BusJson;
import com.ticket.app.backend.booking.web.CinemaCatalogDtos.ScreeningJson;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.TicketType;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * JSON of the buyer endpoints, matching the user app's Booking, Promotion and
 * RunnerDetails. Enum values use the API's names ({@code abaKhqr}, {@code card},
 * {@code female}, {@code XL}, ...). Times are local to Pin's time zone, without an
 * offset. Money is whole US cents.
 */
final class BuyerBookingDtos {

    private BuyerBookingDtos() {
    }

    /**
     * {@code payment} is abaKhqr or card; {@code promoCode} and {@code runner} are
     * optional (a race needs its runner); {@code saveRunner} keeps the runner for the
     * buyer's next race. A bus trip or a screening is booked with {@code seats} (ids such as
     * {@code 3A} or {@code F5}) instead of {@code lines}; a place with {@code visitDate}, the
     * day the tickets are for.
     */
    record BuyBookingRequest(
            @NotBlank(message = "Choose an event.") String eventId,
            List<@NotNull(message = "Choose at least one ticket.") @Valid LineJson> lines,
            List<String> seats,
            @NotBlank(message = "Choose how to pay.") String payment,
            String promoCode,
            @Valid RunnerJson runner,
            Boolean saveRunner,
            LocalDate visitDate) {

        OnlineOrder toOrder() {
            return new OnlineOrder(EventId.parse(eventId),
                    lines == null ? List.of() : lines.stream().map(LineJson::toLine).toList(),
                    payment(payment), promoCode, runner == null ? null : runner.toInput(),
                    Boolean.TRUE.equals(saveRunner), seats == null ? List.of() : seats, visitDate);
        }

        /** Anything but the API's payment names is refused as "Choose how to pay.", not the door sale's wording. */
        private static PaymentMethod payment(String code) {
            try {
                return PaymentMethod.fromCode(code);
            } catch (BusinessRuleException e) {
                throw BusinessRuleException.invalid("Choose how to pay.");
            }
        }
    }

    /** {@code gender} is female, male or other; {@code shirtSize} is XS, S, M, L or XL; {@code email} is optional. */
    record RunnerJson(String name, String phone, String email, String gender, Integer age, String nationality,
                      String emergencyName, String emergencyPhone, String shirtSize) {

        static RunnerJson of(Runner runner) {
            return runner == null ? null : new RunnerJson(runner.name(), runner.phone().value(),
                    runner.email() == null ? null : runner.email().value(), runner.gender().code(), runner.age(),
                    runner.nationality(), runner.emergencyName(), runner.emergencyPhone().value(),
                    runner.shirtSize().code());
        }

        /** Not checked here: the sale checks it only when the event is a race. */
        RunnerInput toInput() {
            return new RunnerInput(name, phone, email, gender, age, nationality, emergencyName, emergencyPhone,
                    shirtSize);
        }
    }

    /** {@code runner} is null when the buyer has none saved. */
    record SavedRunnerResponse(RunnerJson runner) {
    }

    record PromotionResponse(String code, String title, String description, int percentOff, long amountOffCents,
                             long minimumSpendCents) {

        static PromotionResponse of(Promotion promotion) {
            return new PromotionResponse(promotion.code(), promotion.title(), promotion.description(),
                    promotion.percentOff(), promotion.amountOff().cents(), promotion.minimumSpend().cents());
        }
    }

    /**
     * {@code status}: open, checkedIn or cancelled. {@code holderName} is the runner's name
     * for a race, else the buyer's. {@code promoCode} and {@code runner} are null when the
     * booking has none; {@code cancellation} is null unless the business cancelled it.
     * {@code seats} are the seat ids of a bus trip or a screening, e.g. {@code 3A}; empty for any
     * other event. {@code visitDate} is the day a place's tickets are good for; null otherwise.
     */
    record BuyerBookingResponse(String id, String status, String holderName, String payment, String promoCode,
                                long discountCents, long subtotalCents, long totalCents, LocalDateTime bookedAt,
                                List<BookedLine> lines, List<String> seats, LocalDate visitDate, EventJson event,
                                RunnerJson runner, CancellationJson cancellation) {

        static BuyerBookingResponse of(BuyerBooking item, ZoneId zone) {
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

    /** {@code unitPriceCents} is the ticket type's price, which an event keeps after publishing. */
    record BookedLine(String ticketType, int quantity, long unitPriceCents) {

        static BookedLine of(BookingLine line, Event event) {
            long unitPrice = event.ticketType(line.ticketType()).map(type -> type.price().cents()).orElse(0L);
            return new BookedLine(line.ticketType(), line.quantity(), unitPrice);
        }
    }

    /**
     * The event as the catalogue shows it. {@code bus} is set for a bus trip, {@code screening} for a film.
     * {@code imageUrl} is the cover image's address on this server, or null when there is none.
     */
    record EventJson(String id, String name, LocalDateTime startsAt, String venue, String venueDetail, String about,
                     String organiser, String policy, String kind, boolean needsRunnerDetails,
                     List<TicketTypeJson> ticketTypes, BusJson bus, ScreeningJson screening, String imageUrl) {

        static EventJson of(EventOnSale listing) {
            Event event = listing.event();
            EventPage page = listing.page();
            List<TicketType> types = event.ticketTypes();
            return new EventJson(event.id().toString(), event.name(), event.startsAt(), event.venue(),
                    page.venueDetail(), page.about(), listing.organiser(), page.policy(), event.kind().code(),
                    event.kind().needsRunnerDetails(),
                    IntStream.range(0, types.size())
                            .mapToObj(index -> new TicketTypeJson(types.get(index).name(), page.noteFor(index),
                                    types.get(index).price().cents()))
                            .toList(),
                    BusJson.of(listing.bus(), listing.organiser()), ScreeningJson.of(listing.screening()),
                    listing.imageUrl());
        }
    }

    record TicketTypeJson(String name, String description, long priceCents) {
    }

    /**
     * Null unless the business cancelled the booking. {@code reason}: buyerAsked,
     * eventChanged, soldByMistake or other. {@code refundCents}: what Pin pays back to the
     * buyer, everything they paid.
     */
    record CancellationJson(LocalDateTime at, String reason, String businessName, long refundCents) {

        static CancellationJson of(Booking booking, String businessName, ZoneId zone) {
            Cancellation cancellation = booking.cancellation();
            return cancellation == null ? null : new CancellationJson(local(cancellation.at(), zone),
                    cancellation.reason().code(), businessName, booking.refund().cents());
        }
    }

    /** Whole seconds: the database keeps microseconds, so finer times would differ once saved. */
    private static LocalDateTime local(Instant instant, ZoneId zone) {
        return LocalDateTime.ofInstant(instant, zone).truncatedTo(ChronoUnit.SECONDS);
    }
}
