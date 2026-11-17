package com.ticket.app.backend.event.model;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.shared.model.BusinessRuleException;

/**
 * An event a business publishes. Its capacity is the sum of its ticket types'
 * quantities (for a place, each ticket type's quantity is its limit per day). Times
 * are local to the venue. It goes on sale once a Pin admin approves it.
 */
public final class Event {

    public static final int MAX_TICKET_TYPES = 6;

    /** How many days ahead a buyer can book a place, today included: as in the user app. */
    public static final int BOOKING_DAYS = 62;

    private final EventId id;
    private final BusinessId businessId;
    private final String name;
    private final LocalDateTime startsAt;
    private final String venue;
    private final List<TicketType> ticketTypes;
    private final BigDecimal commissionRate;
    /** Null while it waits for approval. */
    private final Instant approvedAt;
    private final EventKind kind;

    private Event(EventId id, BusinessId businessId, String name, LocalDateTime startsAt, String venue,
                  List<TicketType> ticketTypes, BigDecimal commissionRate, Instant approvedAt, EventKind kind) {
        this.id = Objects.requireNonNull(id, "id");
        this.businessId = Objects.requireNonNull(businessId, "businessId");
        this.name = Objects.requireNonNull(name, "name");
        this.startsAt = Objects.requireNonNull(startsAt, "startsAt");
        this.venue = Objects.requireNonNull(venue, "venue");
        this.ticketTypes = List.copyOf(ticketTypes);
        this.commissionRate = Objects.requireNonNull(commissionRate, "commissionRate");
        this.approvedAt = approvedAt;
        this.kind = Objects.requireNonNull(kind, "kind");
    }

    /**
     * Publishes a new event, waiting for an admin's approval. The rules: a name of 3 or
     * more characters, a kind, a date that is not in the past, a venue, and 1 to 6 ticket
     * types with different names.
     *
     * @param today          today where the event happens
     * @param commissionRate percent Pin keeps of online sales
     */
    public static Event publish(BusinessId businessId, EventDraft draft, LocalDate today, BigDecimal commissionRate) {
        String name = strip(draft.name());
        if (name.length() < 3) {
            throw BusinessRuleException.invalid("Give the event a name of at least 3 characters.");
        }
        if (name.length() > 100) {
            throw BusinessRuleException.invalid("Keep the event name under 100 characters.");
        }
        if (draft.kind() == null) {
            throw BusinessRuleException.invalid("Choose what kind of event it is.");
        }
        if (draft.startsAt() == null) {
            throw BusinessRuleException.invalid("Choose the date and start time.");
        }
        if (draft.startsAt().toLocalDate().isBefore(today)) {
            throw BusinessRuleException.invalid("The event date cannot be in the past.");
        }
        String venue = strip(draft.venue());
        if (venue.isEmpty()) {
            throw BusinessRuleException.invalid("Enter the venue.");
        }
        if (venue.length() > 120) {
            throw BusinessRuleException.invalid("Keep the venue under 120 characters.");
        }

        List<TicketType> types = draft.ticketTypes() == null ? List.of() : draft.ticketTypes();
        if (types.isEmpty()) {
            throw BusinessRuleException.invalid("Add at least one ticket type.");
        }
        if (types.size() > MAX_TICKET_TYPES) {
            throw BusinessRuleException.invalid("An event can have at most 6 ticket types.");
        }
        long differentNames = types.stream().map(type -> type.name().toLowerCase(Locale.ROOT)).distinct().count();
        if (differentNames != types.size()) {
            throw BusinessRuleException.invalid("Each ticket type needs a different name.");
        }

        return new Event(EventId.newId(), businessId, name, draft.startsAt(), venue, types, commissionRate, null,
                draft.kind());
    }

    /**
     * An event read back from storage.
     *
     * @param approvedAt when an admin approved it; null while it waits
     */
    public static Event restore(EventId id, BusinessId businessId, String name, LocalDateTime startsAt,
                                String venue, List<TicketType> ticketTypes, BigDecimal commissionRate,
                                Instant approvedAt, EventKind kind) {
        return new Event(id, businessId, name, startsAt, venue, ticketTypes, commissionRate, approvedAt, kind);
    }

    /** An event read back from storage, as a concert. */
    public static Event restore(EventId id, BusinessId businessId, String name, LocalDateTime startsAt,
                                String venue, List<TicketType> ticketTypes, BigDecimal commissionRate,
                                Instant approvedAt) {
        return restore(id, businessId, name, startsAt, venue, ticketTypes, commissionRate, approvedAt,
                EventKind.CONCERT);
    }

    /** An admin puts the event on sale. An event that has ended can no longer be approved. */
    public Event approve(Instant now, LocalDate today) {
        if (isApproved()) {
            throw BusinessRuleException.conflict(name + " is already approved.");
        }
        if (timingOn(today) == EventTiming.PAST) {
            throw BusinessRuleException.conflict(name + " has ended.");
        }
        return new Event(id, businessId, name, startsAt, venue, ticketTypes, commissionRate, now, kind);
    }

    public boolean isApproved() {
        return approvedAt != null;
    }

    /** When an admin approved it, if they have. */
    public Optional<Instant> approvedAt() {
        return Optional.ofNullable(approvedAt);
    }

    /** Tickets can only be sold once an admin has approved the event. */
    public void ensureApproved() {
        if (!isApproved()) {
            throw BusinessRuleException.conflict(
                    "Pin is still reviewing this event. You can sell tickets once it is approved.");
        }
    }

    /** The most tickets that can be sold. */
    public int capacity() {
        return ticketTypes.stream().mapToInt(TicketType::quantity).sum();
    }

    public EventTiming timingOn(LocalDate today) {
        if (kind.isOpenEveryDay()) {
            // A place has no date of its own: it is open today, and every day.
            return EventTiming.TODAY;
        }
        LocalDate day = startsAt.toLocalDate();
        if (day.isBefore(today)) {
            return EventTiming.PAST;
        }
        return day.isAfter(today) ? EventTiming.UPCOMING : EventTiming.TODAY;
    }

    /**
     * Whether buyers can still book it: approved, and not started yet. A place is open every
     * day, so once approved it can be booked at any time.
     */
    public boolean isOnSaleAt(LocalDateTime now) {
        return isApproved() && (kind.isOpenEveryDay() || startsAt.isAfter(now));
    }

    /**
     * Checks the day a buyer chose for a place: from today up to {@value #BOOKING_DAYS} days
     * ahead, today included.
     */
    public void ensureVisitable(LocalDate visitDate, LocalDate today) {
        if (visitDate == null) {
            throw BusinessRuleException.invalid("Choose the day you are visiting.");
        }
        if (visitDate.isBefore(today)) {
            throw BusinessRuleException.invalid("Choose today or a later day.");
        }
        if (visitDate.isAfter(today.plusDays(BOOKING_DAYS - 1))) {
            throw BusinessRuleException.invalid("Tickets can be booked up to " + BOOKING_DAYS + " days ahead.");
        }
    }

    /** Guests can only be checked in on the day of the event. */
    public void ensureCheckInOpenOn(LocalDate today) {
        switch (timingOn(today)) {
            case UPCOMING -> throw BusinessRuleException.conflict("Check-in opens on the day of the event.");
            case PAST -> throw BusinessRuleException.conflict("The event has ended.");
            case TODAY -> {
            }
        }
    }

    /** Tickets can be sold until the event's day is over. */
    public void ensureNotEndedOn(LocalDate today) {
        if (timingOn(today) == EventTiming.PAST) {
            throw BusinessRuleException.conflict("The event has ended.");
        }
    }

    public Optional<TicketType> ticketType(String name) {
        return ticketTypes.stream().filter(type -> type.name().equals(name)).findFirst();
    }

    public boolean belongsTo(BusinessId business) {
        return businessId.equals(business);
    }

    public EventId id() {
        return id;
    }

    public BusinessId businessId() {
        return businessId;
    }

    public String name() {
        return name;
    }

    public LocalDateTime startsAt() {
        return startsAt;
    }

    public String venue() {
        return venue;
    }

    public List<TicketType> ticketTypes() {
        return ticketTypes;
    }

    public EventKind kind() {
        return kind;
    }

    /** Percent Pin keeps of online sales. Door sales carry none. */
    public BigDecimal commissionRate() {
        return commissionRate;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Event that && id.equals(that.id);
    }

    @Override
    public int hashCode() {
        return id.hashCode();
    }

    @Override
    public String toString() {
        return "Event[" + id + ", " + name + "]";
    }

    private static String strip(String text) {
        return text == null ? "" : text.strip();
    }
}
