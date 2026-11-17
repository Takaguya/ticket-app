package com.ticket.app.backend.booking.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.repository.BookingRepository;
import com.ticket.app.backend.booking.model.Promotion;
import com.ticket.app.backend.booking.model.Promotions;
import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.booking.repository.SavedRunnerRepository;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.event.service.CatalogService;
import com.ticket.app.backend.event.service.EventOnSale;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.NotFoundException;
import org.springframework.stereotype.Service;

/** What a buyer sees in the user app: their bookings, the promo codes on offer and their saved runner. */
@Service
public class BuyerBookingService {

    private final BookingRepository bookings;
    private final SavedRunnerRepository savedRunners;
    private final CatalogService catalog;

    public BuyerBookingService(BookingRepository bookings, SavedRunnerRepository savedRunners,
                               CatalogService catalog) {
        this.bookings = bookings;
        this.savedRunners = savedRunners;
        this.catalog = catalog;
    }

    /**
     * The buyer's bookings, the soonest first: by the event's start, or for a place by the day the
     * tickets are for (a place has no date of its own).
     */
    public List<BuyerBooking> bookingsOf(Buyer buyer) {
        List<Booking> mine = bookings.findByBuyer(buyer.id());
        Map<EventId, EventOnSale> events = catalog.detailsOf(mine.stream().map(Booking::eventId).distinct().toList());
        return mine.stream()
                .map(booking -> new BuyerBooking(booking, events.get(booking.eventId())))
                .sorted(Comparator.comparing(BuyerBookingService::when)
                        .thenComparing(item -> item.booking().createdAt()))
                .toList();
    }

    private static LocalDateTime when(BuyerBooking item) {
        LocalDate visit = item.booking().visitDate();
        return visit == null ? item.event().event().startsAt() : visit.atStartOfDay();
    }

    /** One of the buyer's bookings. Another buyer's, or none, is not found. */
    public BuyerBooking bookingOf(Buyer buyer, BookingId id) {
        return bookings.find(id)
                .filter(booking -> booking.isBoughtBy(buyer.id()))
                .map(this::withEvent)
                .orElseThrow(() -> new NotFoundException("This booking does not exist."));
    }

    /** The runner the buyer saved at an earlier race, if any. */
    public Optional<Runner> savedRunner(Buyer buyer) {
        return savedRunners.find(buyer.id());
    }

    /** The promo codes on offer. */
    public List<Promotion> promotions() {
        return Promotions.ON_OFFER;
    }

    private BuyerBooking withEvent(Booking booking) {
        return new BuyerBooking(booking, catalog.details(booking.eventId()));
    }
}
