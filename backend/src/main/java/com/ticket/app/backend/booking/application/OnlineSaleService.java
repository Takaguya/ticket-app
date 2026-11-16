package com.ticket.app.backend.booking.application;

import java.time.Clock;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.event.application.CatalogService;
import com.ticket.app.backend.event.application.EventOnSale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Selling to buyers in the user app. The event is locked while it sells, so two sales
 * can never take the last ticket together, whether they come from the app or the door.
 * How the tickets are checked and priced depends on how the event sells (tickets, seats or a
 * day pass): that is {@link SalesRules}.
 *
 * <p>Paying is simulated: Pin takes no real money yet, so the booking is made as if
 * the payment went through.
 */
@Service
public class OnlineSaleService {

    private final CatalogService catalog;
    private final SalesRulesRegistry rules;
    private final BookingWriter writer;
    private final Clock clock;

    OnlineSaleService(CatalogService catalog, SalesRulesRegistry rules, BookingWriter writer, Clock clock) {
        this.catalog = catalog;
        this.rules = rules;
        this.writer = writer;
        this.clock = clock;
    }

    /**
     * Records the purchase as a new booking, not checked in yet, and keeps the runner for
     * the buyer's next race when they asked. Refused when the event is not on sale (any
     * more), has too few tickets or seats left, or the order breaks the event's rules.
     */
    @Transactional
    public Booking buy(Buyer buyer, OnlineOrder order) {
        EventOnSale onSale = catalog.lockOnSale(order.eventId());
        PreparedSale sale = rules.forKind(onSale.event().kind()).online(buyer, order, onSale, clock.instant());
        return writer.add(sale);
    }
}
