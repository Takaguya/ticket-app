package com.ticket.app.backend.event.dto;

import com.ticket.app.backend.event.model.TicketType;

/** One kind of ticket of an event, as the merchant sees it. */
public record TicketTypeResponse(String name, long priceCents, int quantity) {

    public static TicketTypeResponse of(TicketType type) {
        return new TicketTypeResponse(type.name(), type.price().cents(), type.quantity());
    }
}
