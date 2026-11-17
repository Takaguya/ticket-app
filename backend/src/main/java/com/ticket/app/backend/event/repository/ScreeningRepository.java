package com.ticket.app.backend.event.repository;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.Screening;

/** Where the film details of screenings are kept. They go with their event. */
public interface ScreeningRepository {

    void add(Screening screening);

    /** The screening's details; empty when the event is not a screening. */
    Optional<Screening> find(EventId eventId);

    /** The details of those events that are screenings. */
    Map<EventId, Screening> findAll(Collection<EventId> eventIds);
}
