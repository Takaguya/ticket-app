package com.ticket.app.backend.event.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.event.model.EventDraft;
import com.ticket.app.backend.event.model.EventKind;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/**
 * What the owner fills in to publish an event, matching the merchant app's Event. {@code startsAt} is the
 * local time at the venue, without an offset, e.g. {@code 2026-11-28T06:00:00}. {@code kind}: marathon,
 * concert or show. The rules themselves are checked by the domain.
 */
public record PublishEventRequest(
        String name,
        LocalDateTime startsAt,
        String venue,
        String kind,
        @NotNull(message = "Add at least one ticket type.") List<@NotNull(message = "Fill in every ticket type.") @Valid TicketTypeRequest> ticketTypes) {

    public EventDraft toDraft() {
        return new EventDraft(name, startsAt, venue, ticketTypes.stream().map(TicketTypeRequest::toTicketType).toList(),
                EventKind.fromCode(kind));
    }
}
