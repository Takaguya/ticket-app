package com.ticket.app.backend.booking.application;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.event.application.CatalogService;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.TicketType;
import org.springframework.stereotype.Service;

/**
 * What a buyer sees of the places open every day (temple parks, water parks...): the places
 * on sale, and what is left of each ticket type's daily limit on a day.
 */
@Service
public class PlaceCatalogService {

    private final CatalogService catalog;
    private final BookingRepository bookings;
    private final Clock clock;

    public PlaceCatalogService(CatalogService catalog, BookingRepository bookings, Clock clock) {
        this.catalog = catalog;
        this.bookings = bookings;
        this.clock = clock;
    }

    /** Every place on sale. */
    public List<EventOnSale> places() {
        return catalog.placesOnSale();
    }

    /** One place on sale. Not found when it is not a place, or is no longer on sale. */
    public EventOnSale place(EventId id) {
        return catalog.placeOnSale(id);
    }

    /**
     * What is left of each ticket type on one day.
     *
     * @param left null for a ticket type with no daily limit
     */
    public record Left(String ticketType, Integer left) {
    }

    /**
     * What is left of each ticket type's limit for {@code day}, in the order the place lists
     * them. Refused (400) when the day is before today or more than the days a buyer can
     * book ahead; not found when the place is not on sale.
     */
    public List<Left> availability(EventId id, LocalDate day) {
        EventOnSale place = catalog.placeOnSale(id);
        place.event().ensureVisitable(day, LocalDate.now(clock));
        SalesSummary sales = SalesSummary.of(place.event(), bookings.findByEventVisiting(id, day));
        return place.event().ticketTypes().stream()
                .map(type -> new Left(type.name(), left(type, sales)))
                .toList();
    }

    private static Integer left(TicketType type, SalesSummary sales) {
        return type.hasLimit() ? sales.leftOf(type.name()) : null;
    }
}
