package com.ticket.app.backend.event.domain;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;

/** Where the user app's event pages are kept. */
public interface EventPageRepository {

    Optional<EventPage> find(EventId eventId);

    /** The pages that exist among these events; an event with none is left out. */
    Map<EventId, EventPage> findAll(Collection<EventId> eventIds);

    /** Saves the page, replacing the event's earlier one. */
    void save(EventPage page);
}
