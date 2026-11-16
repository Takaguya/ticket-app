package com.ticket.app.backend.event.web;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventPage;

/**
 * JSON of the catalogue endpoints, matching the user app's EventListing and
 * TicketTier. {@code startsAt} is the local time at the venue, without an offset.
 */
final class CatalogDtos {

    private CatalogDtos() {
    }

    /**
     * {@code kind}: marathon, concert or show. {@code needsRunnerDetails}: booking asks for
     * the runner's details, derived from the kind (a marathon). Text the merchant did not
     * give is an empty string. {@code imageUrl} is the cover image's address on this server
     * (e.g. {@code /images/events/<id>?v=1763300000000}), or null when the event has none.
     */
    record EventListingResponse(String id, String name, LocalDateTime startsAt, String venue, String venueDetail,
                                String about, String organiser, String policy, String kind,
                                boolean needsRunnerDetails, List<TicketTypeListing> ticketTypes, String imageUrl) {

        static EventListingResponse of(EventOnSale listing) {
            Event event = listing.event();
            EventPage page = listing.page();
            return new EventListingResponse(event.id().toString(), event.name(), event.startsAt(), event.venue(),
                    page.venueDetail(), page.about(), listing.organiser(), page.policy(), event.kind().code(),
                    event.kind().needsRunnerDetails(),
                    IntStream.range(0, event.ticketTypes().size())
                            .mapToObj(index -> new TicketTypeListing(event.ticketTypes().get(index).name(),
                                    page.noteFor(index), event.ticketTypes().get(index).price().cents()))
                            .toList(),
                    listing.imageUrl());
        }
    }

    record TicketTypeListing(String name, String description, long priceCents) {
    }
}
