package com.ticket.app.backend.event.model;

import java.time.LocalDateTime;
import java.util.List;

/**
 * What an owner fills in to publish an event. {@link Event#publish} checks it.
 *
 * @param startsAt local time at the venue
 * @param kind     what kind of event it is; required
 */
public record EventDraft(String name, LocalDateTime startsAt, String venue, List<TicketType> ticketTypes,
                         EventKind kind) {

    /** A draft of a concert, for callers that do not choose a kind. */
    public EventDraft(String name, LocalDateTime startsAt, String venue, List<TicketType> ticketTypes) {
        this(name, startsAt, venue, ticketTypes, EventKind.CONCERT);
    }
}
