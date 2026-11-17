package com.ticket.app.backend.booking.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.booking.service.BusCatalogService.Departure;
import com.ticket.app.backend.event.service.EventOnSale;
import com.ticket.app.backend.event.model.BusTrip;

/**
 * The trip as the bus search shows it, matching the user app's BusDeparture. {@code departsAt} is local to
 * Pin's time zone, without an offset. Money is whole US cents. {@code id} is the trip's event ID: what the
 * buyer books. {@code coachType} is the coach as buyers read it, e.g. "Seater · 2+2". {@code imageUrl} is
 * the trip's cover image, or null.
 */
public record DepartureResponse(String id, String routeId, String operatorName, String operatorCode,
                         long operatorColor, String coachType, String origin, String destination,
                         LocalDateTime departsAt, int durationMinutes, long priceCents, List<String> amenities,
                         int seatsLeft, String boardingPoint, String boardingAddress, String about,
                         String imageUrl) {

    public static DepartureResponse of(Departure departure) {
        EventOnSale item = departure.trip();
        BusTrip bus = item.bus();
        long price = item.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents()).orElse(0L);
        return new DepartureResponse(item.event().id().toString(),
                BusNames.routeId(bus.origin(), bus.destination()), item.organiser(),
                BusNames.operatorCode(item.organiser()), BusNames.operatorColor(item.organiser()),
                bus.layout().label(), bus.origin(), bus.destination(), item.event().startsAt(),
                bus.durationMinutes(), price, bus.amenities(), departure.seatsLeft(), item.event().venue(),
                item.page().venueDetail(), item.page().about(), item.imageUrl());
    }
}
