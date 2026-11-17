package com.ticket.app.backend.booking.dto;

/** One kind of ticket of the event inside a booking. */
public record TicketTypeJson(String name, String description, long priceCents) {
}
