package com.ticket.app.backend.event.repository;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventImage;

/** Where events' cover images are kept. */
public interface EventImageRepository {

    /** The event's image with its bytes; empty when it has none. */
    Optional<EventImage> find(EventId eventId);

    /**
     * The version of the image of each of these events that has one ({@link EventImage#version()}),
     * without reading the pictures. An event with none is left out.
     */
    Map<EventId, Long> findVersions(Collection<EventId> eventIds);

    /** Saves the image, replacing the event's earlier one. */
    void save(EventImage image);

    /** Removes the event's image; nothing happens when it has none. */
    void delete(EventId eventId);
}
