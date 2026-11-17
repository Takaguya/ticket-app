package com.ticket.app.backend.booking.dto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import com.ticket.app.backend.event.service.EventOnSale;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.TicketType;

/**
 * The event of a booking as the catalogue shows it. {@code bus} is set for a bus trip, {@code screening} for a film.
 * {@code imageUrl} is the cover image's address on this server, or null when there is none.
 */
public record EventJson(String id, String name, LocalDateTime startsAt, String venue, String venueDetail, String about,
                 String organiser, String policy, String kind, boolean needsRunnerDetails,
                 List<TicketTypeJson> ticketTypes, BusJson bus, ScreeningJson screening, String imageUrl) {

    public static EventJson of(EventOnSale listing) {
        Event event = listing.event();
        EventPage page = listing.page();
        List<TicketType> types = event.ticketTypes();
        return new EventJson(event.id().toString(), event.name(), event.startsAt(), event.venue(),
                page.venueDetail(), page.about(), listing.organiser(), page.policy(), event.kind().code(),
                event.kind().needsRunnerDetails(),
                IntStream.range(0, types.size())
                        .mapToObj(index -> new TicketTypeJson(types.get(index).name(), page.noteFor(index),
                                types.get(index).price().cents()))
                        .toList(),
                BusJson.of(listing.bus(), listing.organiser()), ScreeningJson.of(listing.screening()),
                listing.imageUrl());
    }
}
