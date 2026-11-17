package com.ticket.app.backend.event.service;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Predicate;

import com.ticket.app.backend.business.service.BusinessService;
import com.ticket.app.backend.business.model.Business;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.repository.BusTripRepository;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.repository.EventImageRepository;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.repository.EventPageRepository;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.SaleStyle;
import com.ticket.app.backend.event.repository.EventRepository;
import com.ticket.app.backend.event.model.Screening;
import com.ticket.app.backend.event.repository.ScreeningRepository;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * The events, bus trips, cinema screenings and places buyers can book. One is on sale when
 * an admin approved it, it has not started (a place is open every day, so it never starts),
 * and its business is active: an events business, a bus company, a cinema or an admission
 * business.
 */
@Service
public class CatalogService {

    private static final String NO_LONGER_ON_SALE = "This event is no longer on sale.";

    private final EventRepository events;
    private final EventPageRepository pages;
    private final EventImageRepository images;
    private final BusTripRepository busTrips;
    private final ScreeningRepository screenings;
    private final BusinessService businesses;
    private final Clock clock;

    public CatalogService(EventRepository events, EventPageRepository pages, EventImageRepository images,
                          BusTripRepository busTrips, ScreeningRepository screenings, BusinessService businesses,
                          Clock clock) {
        this.events = events;
        this.pages = pages;
        this.images = images;
        this.busTrips = busTrips;
        this.screenings = screenings;
        this.businesses = businesses;
        this.clock = clock;
    }

    /** Every event on sale that is not a bus trip, a screening or a place, soonest first. */
    public List<EventOnSale> onSale() {
        return onSaleWhere(event -> event.kind().saleStyle() == SaleStyle.TICKETS);
    }

    /** Every place on sale, the one published first coming first. */
    public List<EventOnSale> placesOnSale() {
        return onSaleWhere(event -> event.kind().saleStyle() == SaleStyle.DAY_PASS);
    }

    /** Every bus trip on sale, soonest first. */
    public List<EventOnSale> busTripsOnSale() {
        return onSaleWhere(event -> event.kind() == EventKind.BUS);
    }

    /** Every cinema screening on sale, soonest first. */
    public List<EventOnSale> screeningsOnSale() {
        return onSaleWhere(event -> event.kind() == EventKind.CINEMA);
    }

    private List<EventOnSale> onSaleWhere(Predicate<Event> wanted) {
        LocalDateTime now = LocalDateTime.now(clock);
        List<Event> notStarted = events.findAll().stream()
                .filter(event -> wanted.test(event) && event.isOnSaleAt(now))
                .toList();

        Map<BusinessId, Optional<Business>> sellers = new HashMap<>();
        List<Event> selling = notStarted.stream()
                .filter(event -> sellers.computeIfAbsent(event.businessId(), this::seller).isPresent())
                .toList();

        List<EventId> ids = selling.stream().map(Event::id).toList();
        Map<EventId, EventPage> found = pages.findAll(ids);
        Map<EventId, BusTrip> trips = busTrips.findAll(ids);
        Map<EventId, Screening> shown = screenings.findAll(ids);
        Map<EventId, Long> imageVersions = images.findVersions(ids);
        return selling.stream()
                .map(event -> new EventOnSale(event,
                        found.getOrDefault(event.id(), EventPage.blank(event.id())),
                        sellers.get(event.businessId()).orElseThrow().name(), trips.get(event.id()),
                        shown.get(event.id()), imageVersions.get(event.id())))
                .toList();
    }

    /** One event on sale. Not found when it does not exist or is no longer on sale. */
    public EventOnSale onSale(EventId id) {
        Event event = events.find(id).orElseThrow(CatalogService::unknownEvent);
        return forSale(event).orElseThrow(() -> new NotFoundException(NO_LONGER_ON_SALE));
    }

    /**
     * Like {@link #onSale(EventId)}, and holds the event until the transaction ends, so
     * sales for it happen one at a time. The buyer had the event on screen, so one that
     * went off sale since is a conflict rather than not found.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public EventOnSale lockOnSale(EventId id) {
        Event event = events.findAndLock(id).orElseThrow(CatalogService::unknownEvent);
        return forSale(event).orElseThrow(() -> BusinessRuleException.conflict(NO_LONGER_ON_SALE));
    }

    /**
     * An event a buyer already booked, whatever its state now: ended, or its business
     * suspended since.
     */
    public EventOnSale details(EventId id) {
        Event event = events.find(id).orElseThrow(CatalogService::unknownEvent);
        return describe(event, businesses.find(event.businessId()));
    }

    /**
     * {@link #details(EventId)} for many events at once: three queries however many there
     * are, plus one per business. Events that do not exist are left out.
     */
    public Map<EventId, EventOnSale> detailsOf(Collection<EventId> ids) {
        List<Event> found = events.findAllById(ids);
        List<EventId> foundIds = found.stream().map(Event::id).toList();
        Map<EventId, EventPage> eventPages = pages.findAll(foundIds);
        Map<EventId, BusTrip> trips = busTrips.findAll(foundIds);
        Map<EventId, Screening> shown = screenings.findAll(foundIds);
        Map<EventId, Long> imageVersions = images.findVersions(foundIds);
        Map<BusinessId, Optional<Business>> organisers = new HashMap<>();
        Map<EventId, EventOnSale> details = new HashMap<>();
        for (Event event : found) {
            Optional<Business> organiser = organisers.computeIfAbsent(event.businessId(), businesses::find);
            EventPage page = eventPages.getOrDefault(event.id(), EventPage.blank(event.id()));
            details.put(event.id(), new EventOnSale(event, page, organiser.map(Business::name).orElse(""),
                    trips.get(event.id()), shown.get(event.id()), imageVersions.get(event.id())));
        }
        return details;
    }

    /**
     * One bus trip on sale, with its bus details. Not found when the event does not exist, is
     * not a bus trip, or is no longer on sale.
     */
    public EventOnSale busTripOnSale(EventId id) {
        EventOnSale trip = onSale(id);
        if (trip.bus() == null) {
            throw new NotFoundException("This bus trip does not exist.");
        }
        return trip;
    }

    /**
     * One screening on sale, with its film details. Not found when the event does not exist, is
     * not a screening, or is no longer on sale.
     */
    public EventOnSale screeningOnSale(EventId id) {
        EventOnSale screening = onSale(id);
        if (screening.screening() == null) {
            throw new NotFoundException("This screening does not exist.");
        }
        return screening;
    }

    /**
     * One place on sale. Not found when the event does not exist, is not a place, or is no
     * longer on sale.
     */
    public EventOnSale placeOnSale(EventId id) {
        EventOnSale place = onSale(id);
        if (place.event().kind().saleStyle() != SaleStyle.DAY_PASS) {
            throw new NotFoundException("This place does not exist.");
        }
        return place;
    }

    private Optional<EventOnSale> forSale(Event event) {
        if (!event.isOnSaleAt(LocalDateTime.now(clock))) {
            return Optional.empty();
        }
        return seller(event.businessId()).map(business -> describe(event, Optional.of(business)));
    }

    /**
     * The business, when it may sell to buyers: any active one. What each type of business may
     * publish is decided when it publishes (see {@link EventKind#publishing()}), not here.
     */
    private Optional<Business> seller(BusinessId id) {
        return businesses.find(id).filter(Business::isActive);
    }

    private EventOnSale describe(Event event, Optional<Business> organiser) {
        EventPage page = pages.find(event.id()).orElseGet(() -> EventPage.blank(event.id()));
        return new EventOnSale(event, page, organiser.map(Business::name).orElse(""),
                busTrips.find(event.id()).orElse(null), screenings.find(event.id()).orElse(null),
                images.findVersions(List.of(event.id())).get(event.id()));
    }

    private static NotFoundException unknownEvent() {
        return new NotFoundException("This event does not exist.");
    }
}
