package com.ticket.app.backend.booking.application;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.booking.domain.SeatBooking;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.application.EventService;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.SaleStyle;
import org.springframework.stereotype.Component;

/**
 * Seats chosen on a map: a bus trip, a screening. The seats other live bookings hold are read while
 * the event is locked, so two buyers never get the same seat. At the door nobody chooses: a sale
 * takes the next free seats, front row first.
 */
@Component
class SeatSalesRules implements SalesRules {

    private final BookingRepository bookings;
    private final EventService events;

    SeatSalesRules(BookingRepository bookings, EventService events) {
        this.bookings = bookings;
        this.events = events;
    }

    @Override
    public SaleStyle style() {
        return SaleStyle.SEATS;
    }

    @Override
    public PreparedSale online(Buyer buyer, OnlineOrder order, EventOnSale onSale, Instant now) {
        Event event = onSale.event();
        SalesSummary sales = SalesSummary.of(event, bookings.findByEvent(event.id()));
        Set<String> held = heldSeats(event);
        return id -> Booking.boughtSeatsOnline(id, event, onSale.layout(), buyer, order.seats(), order.payment(),
                order.promoCode(), held, sales, now);
    }

    @Override
    public PreparedSale door(Event event, DoorSale sale, Instant now) {
        SalesSummary sales = SalesSummary.of(event, bookings.findByEvent(event.id()));
        List<String> seats = nextFreeSeats(event, sale);
        return id -> Booking.soldAtDoor(id, event, sale.lines(), sale.buyerPhone(), sale.payment(), sales, seats,
                null, now);
    }

    @Override
    public List<Booking> summaryBookings(Event event) {
        return bookings.findByEvent(event.id());
    }

    private Set<String> heldSeats(Event event) {
        return bookings.findHeldSeats(event.id()).stream().map(SeatBooking::seatId).collect(Collectors.toSet());
    }

    /** One seat for each ticket sold, front row first. The event is locked, so they stay free until saved. */
    private List<String> nextFreeSeats(Event event, DoorSale sale) {
        Set<String> held = heldSeats(event);
        int wanted = sale.lines() == null ? 0 : sale.lines().stream().mapToInt(BookingLine::quantity).sum();
        return events.seatLayout(event.id()).orElseThrow().seatIds().stream()
                .filter(seat -> !held.contains(seat))
                .limit(wanted)
                .toList();
    }
}
