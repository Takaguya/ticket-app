package com.ticket.app.backend.event.domain;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.shared.domain.Money;

/**
 * What the owner of a bus company fills in to publish a trip. It becomes an event (the
 * boarding point is its venue) plus the {@link BusTrip}.
 *
 * @param startsAt        when the bus leaves, local time
 * @param price           per seat
 * @param boardingPoint   where to get on, e.g. a terminal
 * @param boardingAddress the street of the boarding point; may be empty
 * @param about           the tour's description; may be empty
 */
public record BusTripDraft(String origin, String destination, LocalDateTime startsAt, int durationMinutes,
                           SeatLayout layout, Money price, String boardingPoint, String boardingAddress,
                           String about, List<String> amenities) {
}
