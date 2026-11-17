package com.ticket.app.backend.booking.dto;

import java.util.List;

import com.ticket.app.backend.event.model.BusTrip;

/**
 * What a booked trip adds to the event as a buyer sees it. {@code coachType} is seater, vip
 * or sleeper; {@code coachLabel} is how buyers read it. The operator is the bus company.
 */
public record BusJson(String origin, String destination, int durationMinutes, String coachType, String coachLabel,
               List<String> amenities, String operatorCode, long operatorColor) {

    /** Null for an event that is not a bus trip. */
    public static BusJson of(BusTrip trip, String organiser) {
        return trip == null ? null : new BusJson(trip.origin(), trip.destination(), trip.durationMinutes(),
                trip.layout().code(), trip.layout().label(), trip.amenities(),
                BusNames.operatorCode(organiser), BusNames.operatorColor(organiser));
    }
}
