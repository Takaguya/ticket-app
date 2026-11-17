package com.ticket.app.backend.booking.dto;

import java.util.List;
import java.util.stream.IntStream;

import com.ticket.app.backend.event.service.EventOnSale;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.TicketType;

/**
 * A place open every day, matching the user app's AdmissionListing. Money is whole US cents. Text the
 * merchant did not give is an empty string.
 *
 * <p>{@code id} is the place's event ID, which is what a booking sends. {@code dailyLimit} is the
 * most that can be sold of a ticket type for one day; null for no limit. {@code imageUrl} is the
 * place's cover image, or null.
 */
public record PlaceResponse(String id, String name, String venue, String venueDetail, String about, String organiser,
                     String policy, List<PlaceTicketResponse> ticketTypes, String imageUrl) {

    public static PlaceResponse of(EventOnSale listing) {
        Event event = listing.event();
        EventPage page = listing.page();
        List<TicketType> types = event.ticketTypes();
        return new PlaceResponse(event.id().toString(), event.name(), event.venue(), page.venueDetail(),
                page.about(), listing.organiser(), page.policy(),
                IntStream.range(0, types.size())
                        .mapToObj(index -> new PlaceTicketResponse(types.get(index).name(), page.noteFor(index),
                                types.get(index).price().cents(),
                                types.get(index).hasLimit() ? types.get(index).quantity() : null))
                        .toList(),
                listing.imageUrl());
    }
}
