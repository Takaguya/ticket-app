package com.ticket.app.backend.event.repository;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.EventId;

/** Where the bus details of trips are kept. They go with their event. */
public interface BusTripRepository {

    void add(BusTrip trip);

    /** The trip's details; empty when the event is not a bus trip. */
    Optional<BusTrip> find(EventId eventId);

    /** The details of those events that are bus trips. */
    Map<EventId, BusTrip> findAll(Collection<EventId> eventIds);
}
