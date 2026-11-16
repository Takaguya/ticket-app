package com.ticket.app.backend.booking.application;

import java.time.Instant;
import java.util.List;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.Runner;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.booking.domain.SavedRunnerRepository;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.SaleStyle;
import org.springframework.stereotype.Component;

/**
 * Tickets by type up to the event's capacity: a marathon, a concert, a show. A marathon holds one
 * ticket and one runner, whose details are kept for the buyer's next race when they ask.
 */
@Component
class TicketSalesRules implements SalesRules {

    private final BookingRepository bookings;
    private final SavedRunnerRepository savedRunners;

    TicketSalesRules(BookingRepository bookings, SavedRunnerRepository savedRunners) {
        this.bookings = bookings;
        this.savedRunners = savedRunners;
    }

    @Override
    public SaleStyle style() {
        return SaleStyle.TICKETS;
    }

    @Override
    public PreparedSale online(Buyer buyer, OnlineOrder order, EventOnSale onSale, Instant now) {
        Event event = onSale.event();
        SalesSummary sales = SalesSummary.of(event, bookings.findByEvent(event.id()));
        // Only a marathon has a runner: for any other event what was sent is ignored, not checked.
        boolean needsRunner = event.kind().needsRunnerDetails();
        Runner runner = needsRunner && order.runner() != null ? order.runner().toRunner() : null;
        return new PreparedSale() {
            @Override
            public Booking book(BookingId id) {
                return Booking.boughtOnline(id, event, needsRunner, buyer, order.lines(), order.payment(),
                        order.promoCode(), runner, sales, now);
            }

            @Override
            public void saved(Booking booking) {
                if (order.saveRunner() && booking.purchase().runner() != null) {
                    savedRunners.save(buyer.id(), booking.purchase().runner(), now);
                }
            }
        };
    }

    @Override
    public PreparedSale door(Event event, DoorSale sale, Instant now) {
        SalesSummary sales = SalesSummary.of(event, bookings.findByEvent(event.id()));
        return id -> Booking.soldAtDoor(id, event, sale.lines(), sale.buyerPhone(), sale.payment(), sales,
                List.of(), null, now);
    }

    @Override
    public List<Booking> summaryBookings(Event event) {
        return bookings.findByEvent(event.id());
    }
}
