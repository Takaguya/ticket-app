package com.ticket.app.backend.event.domain;

import java.util.List;
import java.util.Locale;
import java.util.Objects;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * What makes an event a bus trip: a tour to a province. The trip leaves its boarding point
 * (the event's venue) at the event's start and takes {@code durationMinutes}. The coach
 * decides the seats. Its only ticket type is {@link #SEAT_TICKET}.
 *
 * @param amenities on board, e.g. Wi-Fi, A/C, Snack
 */
public record BusTrip(EventId eventId, String origin, String destination, int durationMinutes, SeatLayout layout,
                      List<String> amenities) {

    /** The one ticket type of a bus trip: a seat. */
    public static final String SEAT_TICKET = "Seat";

    public static final int MAX_AMENITIES = 8;

    public BusTrip {
        Objects.requireNonNull(eventId, "eventId");
        origin = origin == null ? "" : origin.strip();
        destination = destination == null ? "" : destination.strip();
        if (origin.isEmpty()) {
            throw BusinessRuleException.invalid("Enter where the trip starts.");
        }
        if (destination.isEmpty()) {
            throw BusinessRuleException.invalid("Enter where the trip goes.");
        }
        if (origin.length() > 60 || destination.length() > 60) {
            throw BusinessRuleException.invalid("Keep place names under 60 characters.");
        }
        if (origin.equalsIgnoreCase(destination)) {
            throw BusinessRuleException.invalid("The trip must go somewhere other than where it starts.");
        }
        if (durationMinutes < 10 || durationMinutes > 24 * 60) {
            throw BusinessRuleException.invalid("The trip takes between 10 minutes and 24 hours.");
        }
        if (layout == null || layout.isHall()) {
            throw BusinessRuleException.invalid("Choose the kind of coach.");
        }
        amenities = cleaned(amenities);
    }

    /** The name of the event this trip is: {@code Phnom Penh to Siem Reap}. */
    public String title() {
        return origin + " to " + destination;
    }

    /** The trip's total number of seats. */
    public int capacity() {
        return layout.capacity();
    }

    private static List<String> cleaned(List<String> amenities) {
        List<String> kept = (amenities == null ? List.<String>of() : amenities).stream()
                .map(String::strip)
                .filter(name -> !name.isEmpty())
                .distinct()
                .toList();
        if (kept.size() > MAX_AMENITIES) {
            throw BusinessRuleException.invalid("List at most " + MAX_AMENITIES + " things on board.");
        }
        if (kept.stream().anyMatch(name -> name.length() > 24)) {
            throw BusinessRuleException.invalid("Keep each thing on board under 24 characters.");
        }
        if (kept.stream().map(name -> name.toLowerCase(Locale.ROOT)).distinct().count() != kept.size()) {
            throw BusinessRuleException.invalid("List each thing on board once.");
        }
        return kept;
    }
}
