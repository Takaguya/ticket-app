package com.ticket.app.backend.event.dto;

/** One kind of ticket of an event in the catalogue, matching the user app's TicketTier. */
public record TicketTypeListing(String name, String description, long priceCents) {
}
