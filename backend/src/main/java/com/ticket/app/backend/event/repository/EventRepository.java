package com.ticket.app.backend.event.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;

/** Where events and their ticket types are kept. */
public interface EventRepository {

    void add(Event event);

    Optional<Event> find(EventId id);

    /**
     * The event, held until the transaction ends. Sales for one event lock it, so they
     * happen one after the other and never sell more than its capacity.
     */
    Optional<Event> findAndLock(EventId id);

    /** The events that exist among these IDs, earliest first. */
    List<Event> findAllById(Collection<EventId> ids);

    /** The business's events, earliest first. */
    List<Event> findByBusiness(BusinessId businessId);

    /** Every event of every business, earliest first. */
    List<Event> findAll();

    /** Saves when the event was approved. */
    void updateApproval(Event event);
}
