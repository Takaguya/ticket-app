package com.ticket.app.backend.booking.dto;

/** One kind of ticket of a place; {@code dailyLimit} is null for no limit. */
public record PlaceTicketResponse(String name, String description, long priceCents, Integer dailyLimit) {
}
