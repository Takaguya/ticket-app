package com.ticket.app.backend.event.application;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.ticket.app.backend.business.application.BusinessService;
import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.BusTripDraft;
import com.ticket.app.backend.event.domain.BusTripRepository;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventDraft;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.EventPageRepository;
import com.ticket.app.backend.event.domain.EventRepository;
import com.ticket.app.backend.event.domain.PlaceDraft;
import com.ticket.app.backend.event.domain.Screening;
import com.ticket.app.backend.event.domain.ScreeningDraft;
import com.ticket.app.backend.event.domain.ScreeningRepository;
import com.ticket.app.backend.event.domain.SeatLayout;
import com.ticket.app.backend.event.domain.TicketType;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Publishing and finding events. A member only ever sees their own business's
 * events: anyone else's answer as not found.
 */
@Service
public class EventService {

    private final EventRepository events;
    private final BusTripRepository busTrips;
    private final ScreeningRepository screenings;
    private final EventPageRepository pages;
    private final BusinessService businesses;
    private final Clock clock;
    private final PinProperties properties;

    public EventService(EventRepository events, BusTripRepository busTrips, ScreeningRepository screenings,
                        EventPageRepository pages, BusinessService businesses, Clock clock,
                        PinProperties properties) {
        this.events = events;
        this.busTrips = busTrips;
        this.screenings = screenings;
        this.pages = pages;
        this.businesses = businesses;
        this.clock = clock;
        this.properties = properties;
    }

    /** The bus details of a trip; empty when the event is not a bus trip. */
    public Optional<BusTrip> busTrip(EventId id) {
        return busTrips.find(id);
    }

    /** The bus details of those of these events that are bus trips, in one query. */
    public Map<EventId, BusTrip> busTripsOf(Collection<Event> someEvents) {
        return busTrips.findAll(someEvents.stream()
                .filter(event -> event.kind() == EventKind.BUS)
                .map(Event::id)
                .toList());
    }

    /** The film details of a screening; empty when the event is not a screening. */
    public Optional<Screening> screening(EventId id) {
        return screenings.find(id);
    }

    /** The film details of those of these events that are screenings, in one query. */
    public Map<EventId, Screening> screeningsOf(Collection<Event> someEvents) {
        return screenings.findAll(someEvents.stream()
                .filter(event -> event.kind() == EventKind.CINEMA)
                .map(Event::id)
                .toList());
    }

    /** The seats of a bus trip or a screening; empty for any other event. */
    public Optional<SeatLayout> seatLayout(EventId id) {
        return busTrips.find(id).map(BusTrip::layout).or(() -> screenings.find(id).map(Screening::layout));
    }

    /**
     * Publishes an event for the owner's business, at Pin's current commission rate.
     * It waits for an admin's approval before it goes on sale.
     */
    @Transactional
    public Event publish(StaffMember owner, EventDraft draft) {
        owner.business().ensureCanPublish();
        // A kind with a form of its own is not published with the ordinary one, and a business
        // that has such a kind publishes only that.
        if (draft.kind() != null && draft.kind().publishing().isPresent()) {
            EventKind.Publishing own = draft.kind().publishing().get();
            throw BusinessRuleException.invalid("Publish " + own.plural() + " with the " + own.form() + ".");
        }
        EventKind.ownedBy(owner.business().type()).flatMap(EventKind::publishing).ifPresent(own -> {
            throw BusinessRuleException.conflict(own.publisher() + " publishes " + own.plural() + ", not events.");
        });
        Event event = Event.publish(owner.businessId(), draft, today(), properties.commissionRate());
        events.add(event);
        return event;
    }

    /**
     * Publishes a bus trip for the owner's bus company: an event of kind bus, named after
     * its route, whose venue is the boarding point and whose only ticket type is a seat,
     * with as many seats for sale as the coach has. It waits for an admin's approval like
     * any event.
     */
    @Transactional
    public Event publishBusTrip(StaffMember owner, BusTripDraft draft) {
        requirePublisher(owner, EventKind.BUS);
        String address = draft.boardingAddress() == null ? "" : draft.boardingAddress().strip();
        String about = draft.about() == null ? "" : draft.about().strip();
        if (address.length() > 120) {
            throw BusinessRuleException.invalid("Keep the boarding address under 120 characters.");
        }
        if (about.length() > 2000) {
            throw BusinessRuleException.invalid("Keep the trip description under 2000 characters.");
        }
        if (draft.price() == null) {
            throw BusinessRuleException.invalid("Enter the price of a seat (0 for free).");
        }

        // Checks the route and the coach first: they name the event.
        BusTrip checked = new BusTrip(EventId.newId(), draft.origin(), draft.destination(),
                draft.durationMinutes(), draft.layout(), draft.amenities());
        EventDraft eventDraft = new EventDraft(checked.title(), draft.startsAt(), draft.boardingPoint(),
                List.of(new TicketType(BusTrip.SEAT_TICKET, draft.price(), checked.capacity())), EventKind.BUS);
        Event event = Event.publish(owner.businessId(), eventDraft, today(), properties.commissionRate());
        BusTrip trip = new BusTrip(event.id(), checked.origin(), checked.destination(), checked.durationMinutes(),
                checked.layout(), checked.amenities());

        events.add(event);
        busTrips.add(trip);
        pages.save(new EventPage(event.id(), address, about, "", List.of()));
        return event;
    }

    /**
     * Publishes a screening for the owner's cinema: an event of kind cinema, named after the
     * film, whose venue is the cinema and whose only ticket type is a seat, with as many seats
     * for sale as the hall has. It waits for an admin's approval like any event.
     */
    @Transactional
    public Event publishScreening(StaffMember owner, ScreeningDraft draft) {
        requirePublisher(owner, EventKind.CINEMA);
        String area = draft.theatreArea() == null ? "" : draft.theatreArea().strip();
        String about = draft.about() == null ? "" : draft.about().strip();
        if (area.length() > 120) {
            throw BusinessRuleException.invalid("Keep the cinema's address under 120 characters.");
        }
        if (about.length() > 2000) {
            throw BusinessRuleException.invalid("Keep the film's description under 2000 characters.");
        }
        if (draft.price() == null) {
            throw BusinessRuleException.invalid("Enter the price of a seat (0 for free).");
        }

        // Checks the film and the hall first: they name the event.
        Screening checked = new Screening(EventId.newId(), draft.filmTitle(), draft.rating(), draft.genre(),
                draft.runtimeMinutes(), draft.hall(), draft.layout());
        EventDraft eventDraft = new EventDraft(checked.filmTitle(), draft.startsAt(), draft.theatre(),
                List.of(new TicketType(BusTrip.SEAT_TICKET, draft.price(), checked.capacity())), EventKind.CINEMA);
        Event event = Event.publish(owner.businessId(), eventDraft, today(), properties.commissionRate());
        Screening screening = new Screening(event.id(), checked.filmTitle(), checked.rating(), checked.genre(),
                checked.runtimeMinutes(), checked.hall(), checked.layout());

        events.add(event);
        screenings.add(screening);
        pages.save(new EventPage(event.id(), area, about, "", List.of()));
        return event;
    }

    /**
     * Publishes a place for the owner's admission business: an event of kind admission that is
     * open every day. Its date is the day it was published, only a placeholder; each ticket type's
     * quantity is its limit per day. The event page keeps where it is, what it is about, its
     * policy and a note for each ticket type. It waits for an admin's approval like any event.
     */
    @Transactional
    public Event publishPlace(StaffMember owner, PlaceDraft draft) {
        requirePublisher(owner, EventKind.ADMISSION);
        String detail = draft.venueDetail() == null ? "" : draft.venueDetail().strip();
        String about = draft.about() == null ? "" : draft.about().strip();
        String policy = draft.policy() == null ? "" : draft.policy().strip();
        if (detail.length() > 120) {
            throw BusinessRuleException.invalid("Keep the address under 120 characters.");
        }
        if (about.length() > 2000) {
            throw BusinessRuleException.invalid("Keep the description under 2000 characters.");
        }
        if (policy.length() > 200) {
            throw BusinessRuleException.invalid("Keep the refund policy under 200 characters.");
        }
        if (draft.notes().stream().anyMatch(note -> note != null && note.strip().length() > 80)) {
            throw BusinessRuleException.invalid("Keep each ticket description under 80 characters.");
        }

        EventDraft eventDraft = new EventDraft(draft.name(), today().atStartOfDay(), draft.venue(),
                draft.toTicketTypes(), EventKind.ADMISSION);
        Event event = Event.publish(owner.businessId(), eventDraft, today(), properties.commissionRate());
        events.add(event);
        pages.save(new EventPage(event.id(), detail, about, policy, draft.notes()));
        return event;
    }

    /**
     * An admin puts the event on sale. Its business must be approved first, so an
     * approved event can always sell unless the business is suspended later.
     */
    @Transactional
    public Event approve(EventId id) {
        Event event = events.findAndLock(id).orElseThrow(EventService::notFound);
        businesses.find(event.businessId())
                .filter(Business::isActive)
                .orElseThrow(() -> BusinessRuleException.conflict(
                        "Approve the business first. Its events can go on sale once it is active."));
        Event approved = event.approve(clock.instant(), today());
        events.updateApproval(approved);
        return approved;
    }

    public List<Event> eventsOf(StaffMember member) {
        return eventsOf(member.businessId());
    }

    public List<Event> eventsOf(BusinessId business) {
        return events.findByBusiness(business);
    }

    /** Every business's events, earliest first. For the back office. */
    public List<Event> all() {
        return events.findAll();
    }

    /** One of the member's business's events. */
    public Event eventOf(StaffMember member, EventId id) {
        return events.find(id)
                .filter(event -> event.belongsTo(member.businessId()))
                .orElseThrow(EventService::notFound);
    }

    /**
     * Like {@link #eventOf}, and holds the event until the transaction ends, so sales
     * for it happen one at a time.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public Event lockEventOf(StaffMember member, EventId id) {
        return events.findAndLock(id)
                .filter(event -> event.belongsTo(member.businessId()))
                .orElseThrow(EventService::notFound);
    }

    /** Any business's event, e.g. to name the event a scanned ticket is really for. */
    public Optional<Event> find(EventId id) {
        return events.find(id);
    }

    /**
     * The owner's business may publish this kind, which has a form and a type of business of its
     * own: it must be able to publish at all, and be of that type.
     */
    private static void requirePublisher(StaffMember owner, EventKind kind) {
        owner.business().ensureCanPublish();
        EventKind.Publishing own = kind.publishing().orElseThrow();
        if (owner.business().type() != own.businessType()) {
            throw BusinessRuleException.conflict("Only " + own.publishers() + " publish " + own.plural() + ".");
        }
    }

    /** Today where Pin's events happen. */
    public LocalDate today() {
        return LocalDate.now(clock);
    }

    private static NotFoundException notFound() {
        return new NotFoundException("This event does not exist.");
    }
}
