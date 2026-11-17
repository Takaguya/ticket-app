package com.ticket.app.backend.event.dto;

import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.Money;
import jakarta.validation.constraints.NotNull;

/** One kind of ticket of an event being published, matching the merchant app's TicketType. */
public record TicketTypeRequest(
        String name,
        @NotNull(message = "Enter a price for every ticket type (0 for free).") Long priceCents,
        @NotNull(message = "Enter how many tickets of each type are for sale.") Integer quantity) {

    public TicketType toTicketType() {
        return new TicketType(name, Money.ofCents(priceCents), quantity);
    }
}
