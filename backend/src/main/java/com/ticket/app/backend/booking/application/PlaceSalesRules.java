package com.ticket.app.backend.booking.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.SaleStyle;
import org.springframework.stereotype.Component;

/**
 * A place open every day (a temple park, a water park): tickets by type for one visit day, with an
 * optional limit per ticket type per day. Only the bookings of that day are counted, so each day
 * has its own limits. At the door a sale is for today, the numbers are today's visitors, and the
 * places of one business share a gate.
 */
@Component
class PlaceSalesRules implements SalesRules {

    private final BookingRepository bookings;
    private final Clock clock;

    PlaceSalesRules(BookingRepository bookings, Clock clock) {
        this.bookings = bookings;
        this.clock = clock;
    }

    @Override
    public SaleStyle style() {
        return SaleStyle.DAY_PASS;
    }

    @Override
    public PreparedSale online(Buyer buyer, OnlineOrder order, EventOnSale onSale, Instant now) {
        Event event = onSale.event();
        LocalDate today = today();
        // Checked first, so a bad day is refused before any bookings are read.
        event.ensureVisitable(order.visitDate(), today);
        SalesSummary sales = SalesSummary.of(event, bookings.findByEventVisiting(event.id(), order.visitDate()));
        return id -> Booking.boughtPlaceOnline(id, event, buyer, order.lines(), order.payment(), order.promoCode(),
                order.visitDate(), today, sales, now);
    }

    @Override
    public PreparedSale door(Event event, DoorSale sale, Instant now) {
        LocalDate today = today();
        SalesSummary sales = SalesSummary.of(event, bookings.findByEventVisiting(event.id(), today));
        return id -> Booking.soldAtDoor(id, event, sale.lines(), sale.buyerPhone(), sale.payment(), sales,
                List.of(), today, now);
    }

    @Override
    public List<Booking> summaryBookings(Event event) {
        return bookings.findByEventVisiting(event.id(), today());
    }

    /** A business's places share one gate: scanning at one admits a ticket for another of its places. */
    @Override
    public boolean sharesGate(StaffMember staff, Event scanned, Event ticketEvent) {
        return ticketEvent.kind().saleStyle() == SaleStyle.DAY_PASS && ticketEvent.belongsTo(staff.businessId());
    }

    private LocalDate today() {
        return LocalDate.now(clock);
    }
}
