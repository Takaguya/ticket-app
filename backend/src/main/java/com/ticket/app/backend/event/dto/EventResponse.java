package com.ticket.app.backend.event.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventImage;
import com.ticket.app.backend.event.model.Screening;

/**
 * An event as the merchant sees it. {@code startsAt} is the local time at the venue, without an offset.
 * {@code approved} is false while the event waits for a Pin admin; it cannot be sold until then.
 * {@code kind}: marathon, concert, show, bus, cinema or admission. {@code bus} is set for a bus trip only,
 * {@code screening} for a cinema screening only. {@code imageUrl} is the cover image's address on this
 * server (e.g. {@code /images/events/<id>?v=1763300000000}), or null when the event has none.
 */
public record EventResponse(String id, String name, LocalDateTime startsAt, String venue, double commissionRate,
                     int capacity, boolean approved, String kind, List<TicketTypeResponse> ticketTypes,
                     BusJson bus, ScreeningResponse screening, String imageUrl) {

    public static EventResponse of(Event event) {
        return of(event, null, null);
    }

    public static EventResponse of(Event event, BusTrip trip, Screening screening) {
        return new EventResponse(event.id().toString(), event.name(), event.startsAt(), event.venue(),
                event.commissionRate().doubleValue(), event.capacity(), event.isApproved(), event.kind().code(),
                event.ticketTypes().stream().map(TicketTypeResponse::of).toList(), BusJson.of(trip),
                ScreeningResponse.of(screening), null);
    }

    /** This response with the address of the event's cover image, from {@link EventImage#version()}. */
    public EventResponse withImageVersion(Long version) {
        return new EventResponse(id, name, startsAt, venue, commissionRate, capacity, approved, kind, ticketTypes,
                bus, screening, EventImage.urlOf(EventId.parse(id), version));
    }
}
