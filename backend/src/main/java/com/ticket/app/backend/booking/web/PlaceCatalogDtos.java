package com.ticket.app.backend.booking.web;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.IntStream;

import com.ticket.app.backend.booking.application.PlaceCatalogService.Left;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.TicketType;

/**
 * JSON of the place endpoints, matching the user app's AdmissionListing and TicketTier. Money is
 * whole US cents. Text the merchant did not give is an empty string.
 */
final class PlaceCatalogDtos {

    private PlaceCatalogDtos() {
    }

    /**
     * {@code id} is the place's event ID, which is what a booking sends. {@code dailyLimit} is the
     * most that can be sold of a ticket type for one day; null for no limit. {@code imageUrl} is the
     * place's cover image, or null.
     */
    record PlaceResponse(String id, String name, String venue, String venueDetail, String about, String organiser,
                         String policy, List<PlaceTicketResponse> ticketTypes, String imageUrl) {

        static PlaceResponse of(EventOnSale listing) {
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

    record PlaceTicketResponse(String name, String description, long priceCents, Integer dailyLimit) {
    }

    /** What is left on one day; {@code left} is null for a ticket type with no limit. */
    record AvailabilityResponse(LocalDate date, List<LeftResponse> ticketTypes) {

        static AvailabilityResponse of(LocalDate date, List<Left> left) {
            return new AvailabilityResponse(date, left.stream()
                    .map(item -> new LeftResponse(item.ticketType(), item.left()))
                    .toList());
        }
    }

    record LeftResponse(String name, Integer left) {
    }
}
