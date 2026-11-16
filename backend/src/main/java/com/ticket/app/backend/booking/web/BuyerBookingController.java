package com.ticket.app.backend.booking.web;

import java.time.Clock;
import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.booking.application.BuyerBooking;
import com.ticket.app.backend.booking.application.BuyerBookingService;
import com.ticket.app.backend.booking.application.OnlineSaleService;
import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.web.BuyerBookingDtos.BuyBookingRequest;
import com.ticket.app.backend.booking.web.BuyerBookingDtos.BuyerBookingResponse;
import com.ticket.app.backend.booking.web.BuyerBookingDtos.PromotionResponse;
import com.ticket.app.backend.booking.web.BuyerBookingDtos.RunnerJson;
import com.ticket.app.backend.booking.web.BuyerBookingDtos.SavedRunnerResponse;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.shared.domain.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Buying tickets in the user app, and the buyer's own bookings. Merchants see the same
 * bookings, as online bookings, through the {@code /merchant} endpoints.
 */
@RestController
@RequestMapping("/buyer")
class BuyerBookingController {

    private final OnlineSaleService sales;
    private final BuyerBookingService bookings;
    private final ZoneId zone;

    BuyerBookingController(OnlineSaleService sales, BuyerBookingService bookings, Clock clock) {
        this.sales = sales;
        this.bookings = bookings;
        this.zone = clock.getZone();
    }

    /** The promo codes on offer. */
    @GetMapping("/promotions")
    List<PromotionResponse> promotions() {
        return bookings.promotions().stream().map(PromotionResponse::of).toList();
    }

    /** The runner the buyer saved at an earlier race, or {@code {"runner": null}}. */
    @GetMapping("/runner")
    SavedRunnerResponse savedRunner(@AuthenticationPrincipal Buyer me) {
        return new SavedRunnerResponse(bookings.savedRunner(me).map(RunnerJson::of).orElse(null));
    }

    /**
     * Buys tickets. Pin prices the order; paying is simulated. Refused when the event
     * is no longer on sale (409) or has too few tickets left (409), and for a missing
     * runner, a wrong promo code or more than 8 tickets (400).
     */
    @PostMapping("/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    BuyerBookingResponse buy(@AuthenticationPrincipal Buyer me, @Valid @RequestBody BuyBookingRequest request) {
        Booking booking = sales.buy(me, request.toOrder());
        return BuyerBookingResponse.of(bookings.bookingOf(me, booking.id()), zone);
    }

    /** The buyer's bookings, the soonest event first. */
    @GetMapping("/bookings")
    List<BuyerBookingResponse> list(@AuthenticationPrincipal Buyer me) {
        return bookings.bookingsOf(me).stream().map(item -> BuyerBookingResponse.of(item, zone)).toList();
    }

    /** One booking; 404 when the ID is malformed, unknown or another buyer's. */
    @GetMapping("/bookings/{bookingId}")
    BuyerBookingResponse one(@AuthenticationPrincipal Buyer me, @PathVariable String bookingId) {
        BookingId id = BookingId.parse(bookingId)
                .orElseThrow(() -> new NotFoundException("This booking does not exist."));
        BuyerBooking found = bookings.bookingOf(me, id);
        return BuyerBookingResponse.of(found, zone);
    }
}
