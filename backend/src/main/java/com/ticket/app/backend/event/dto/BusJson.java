package com.ticket.app.backend.event.dto;

import java.util.List;

import com.ticket.app.backend.event.model.BusTrip;

/** {@code coachType}: seater, vip or sleeper; {@code coachLabel} is how buyers see it, e.g. "Seater · 2+2". */
public record BusJson(String origin, String destination, int durationMinutes, String coachType, String coachLabel,
               int seats, List<String> amenities) {

    /** Null for an event that is not a bus trip. */
    public static BusJson of(BusTrip trip) {
        return trip == null ? null : new BusJson(trip.origin(), trip.destination(), trip.durationMinutes(),
                trip.layout().code(), trip.layout().label(), trip.capacity(), trip.amenities());
    }
}
