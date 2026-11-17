package com.ticket.app.backend.booking.dto;

/** How many of one ticket type are left on a day; null for a ticket type with no limit. */
public record LeftResponse(String name, Integer left) {
}
