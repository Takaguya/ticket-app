package com.ticket.app.backend.booking.service;

import java.util.List;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.repository.BookingRepository;
import com.ticket.app.backend.booking.model.BookingSearch;
import com.ticket.app.backend.booking.model.SalesSummary;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.event.service.EventService;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import org.springframework.stereotype.Service;

/** Reading an event's bookings and sales. Only for the event's own business. */
@Service
public class BookingQueryService {

    private final BookingRepository bookings;
    private final EventService events;
    private final SalesRulesRegistry rules;

    BookingQueryService(BookingRepository bookings, EventService events, SalesRulesRegistry rules) {
        this.bookings = bookings;
        this.events = events;
        this.rules = rules;
    }

    /** The event and its bookings matching {@code search}, sorted by buyer name. */
    public EventBookings search(StaffMember member, EventId eventId, BookingSearch search) {
        Event event = events.eventOf(member, eventId);
        return new EventBookings(event, search.apply(bookings.findByEvent(eventId)));
    }

    /** Every booking of the member's business, for all its events. */
    public List<Booking> allOf(StaffMember member) {
        return bookings.findByBusiness(member.businessId());
    }

    /**
     * The event's numbers. A place has no day of its own, so its numbers are today's visits:
     * what has sold for today, how many came, and what is left of today's limits.
     */
    public SalesSummary summary(StaffMember member, EventId eventId) {
        Event event = events.eventOf(member, eventId);
        return SalesSummary.of(event, rules.forKind(event.kind()).summaryBookings(event));
    }

    /** An event with some of its bookings, e.g. for the CSV export. */
    public record EventBookings(Event event, List<Booking> bookings) {
    }
}
