package com.ticket.app.backend.event.dto;

import java.util.List;

import com.ticket.app.backend.event.model.PlaceDraft;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/**
 * What the owner of an admission business fills in to publish a place that is open every day.
 * {@code venueDetail} (where it is), {@code about} and {@code policy} are optional. Each ticket
 * type has a {@code priceCents} and an optional {@code dailyLimit}: the most sold for one day,
 * none when left out.
 */
public record PublishPlaceRequest(
        String name,
        String venue,
        String venueDetail,
        String about,
        String policy,
        List<@NotNull(message = "Fill in every ticket type.") @Valid PlaceTicketRequest> ticketTypes) {

    public PlaceDraft toDraft() {
        return new PlaceDraft(name, venue, venueDetail, about, policy, ticketTypes == null ? List.of()
                : ticketTypes.stream().map(PlaceTicketRequest::toTicket).toList());
    }
}
