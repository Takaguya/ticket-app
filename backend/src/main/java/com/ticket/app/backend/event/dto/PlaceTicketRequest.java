package com.ticket.app.backend.event.dto;

import com.ticket.app.backend.event.model.PlaceDraft;
import com.ticket.app.backend.shared.model.Money;
import jakarta.validation.constraints.NotNull;

/** One kind of ticket of a place being published, with its optional daily limit. */
public record PlaceTicketRequest(
        String name,
        String description,
        @NotNull(message = "Enter the price of every ticket type (0 for free).") Long priceCents,
        Integer dailyLimit) {

    public PlaceDraft.PlaceTicket toTicket() {
        return new PlaceDraft.PlaceTicket(name, description, Money.ofCents(priceCents), dailyLimit);
    }
}
