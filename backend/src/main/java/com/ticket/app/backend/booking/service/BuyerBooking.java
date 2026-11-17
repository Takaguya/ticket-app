package com.ticket.app.backend.booking.service;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.event.service.EventOnSale;

/**
 * A booking with the event it is for, as the buyer sees it. The event is shown as it is
 * now, even when it has ended or its business has been suspended since.
 */
public record BuyerBooking(Booking booking, EventOnSale event) {
}
