package com.ticket.app.backend.booking.application;

import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.event.domain.EventId;

/**
 * What a buyer asks for in the user app: tickets, how they pay, a promo code and, for
 * a race, the runner; for a bus trip, the seats instead of tickets.
 *
 * @param lines      the tickets by type; empty for a bus trip
 * @param promoCode  as typed; null for none
 * @param runner     as sent, not checked; null when the buyer gave none. Ignored unless
 *                   the event is a race
 * @param saveRunner keep the runner for the buyer's next race
 * @param seats      the seat ids chosen on a bus trip, e.g. {@code 3A}; empty for any other event
 * @param visitDate  the day chosen for a place's tickets; null for anything else. Ignored unless
 *                   the event is a place
 */
public record OnlineOrder(EventId eventId, List<BookingLine> lines, PaymentMethod payment, String promoCode,
                          RunnerInput runner, boolean saveRunner, List<String> seats, LocalDate visitDate) {
}
