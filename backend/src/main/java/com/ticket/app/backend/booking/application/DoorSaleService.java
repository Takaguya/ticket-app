package com.ticket.app.backend.booking.application;

import java.time.Clock;
import java.util.Optional;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingAttempts;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.application.EventService;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Selling at the entrance. The event is locked while it sells, so two sales can
 * never take the last ticket together, and a sale sent again after a lost answer is
 * found instead of recorded twice. What a door sale holds (tickets, the next free seats, today's
 * visitors) depends on how the event sells: that is {@link SalesRules}.
 */
@Service
public class DoorSaleService {

    private final BookingRepository bookings;
    private final BookingAttempts attempts;
    private final EventService events;
    private final SalesRulesRegistry rules;
    private final BookingWriter writer;
    private final Clock clock;

    DoorSaleService(BookingRepository bookings, BookingAttempts attempts, EventService events,
                    SalesRulesRegistry rules, BookingWriter writer, Clock clock) {
        this.bookings = bookings;
        this.attempts = attempts;
        this.events = events;
        this.rules = rules;
        this.writer = writer;
        this.clock = clock;
    }

    /**
     * Records the sale as a new booking, not checked in yet. If this sale's attempt
     * was already recorded (its answer was lost), returns that booking instead.
     */
    @Transactional
    public Booking sell(StaffMember seller, EventId eventId, DoorSale sale) {
        Event event = events.lockEventOf(seller, eventId);
        Optional<Booking> earlier = alreadyRecorded(seller, event, sale);
        if (earlier.isPresent()) {
            return earlier.get();
        }

        seller.business().ensureCanSell();
        event.ensureApproved();
        event.ensureNotEndedOn(events.today());
        Booking booking = writer.add(rules.forKind(event.kind()).door(event, sale, clock.instant()));
        if (sale.attempt() != null) {
            attempts.record(sale.attempt(), BookingAttempts.Kind.DOOR_SALE, booking.id(), seller.id());
        }
        return booking;
    }

    /** The booking this seller's attempt already made for this event, if any. */
    private Optional<Booking> alreadyRecorded(StaffMember seller, Event event, DoorSale sale) {
        if (sale.attempt() == null) {
            return Optional.empty();
        }
        return attempts.bookingOf(sale.attempt(), BookingAttempts.Kind.DOOR_SALE, seller.id())
                .flatMap(bookings::find)
                .filter(booking -> booking.isFor(event.id()));
    }
}
