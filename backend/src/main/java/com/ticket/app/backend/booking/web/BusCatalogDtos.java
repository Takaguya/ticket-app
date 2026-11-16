package com.ticket.app.backend.booking.web;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

import com.ticket.app.backend.booking.application.BusCatalogService.Departure;
import com.ticket.app.backend.booking.application.BusCatalogService.Route;
import com.ticket.app.backend.booking.application.BusCatalogService.SeatMap;
import com.ticket.app.backend.booking.application.BusCatalogService.SeatView;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.BusTrip;

/**
 * JSON of the bus endpoints, matching the user app's BusRoute, BusDeparture and SeatMap.
 * {@code departsAt} is local to Pin's time zone, without an offset. Money is whole US cents.
 */
final class BusCatalogDtos {

    /** The badge colours of bus companies, as 0xAARRGGBB; a company always gets the same one. */
    private static final long[] COLOURS = {0xFF1E8A72L, 0xFF0151A6L, 0xFFD9822BL, 0xFF8E44ADL, 0xFFC0392BL};

    private BusCatalogDtos() {
    }

    /** {@code id} names the route, e.g. {@code phnom-penh-siem-reap}. */
    record RouteResponse(String id, String origin, String destination, int durationMinutes, int operatorCount,
                         int tripCount, long fromPriceCents) {

        static RouteResponse of(Route route) {
            return new RouteResponse(routeId(route.origin(), route.destination()), route.origin(),
                    route.destination(), route.durationMinutes(), route.companies(), route.trips(),
                    route.fromPriceCents());
        }
    }

    /**
     * The trip as the bus search shows it. {@code id} is the trip's event ID: what the buyer
     * books. {@code coachType} is the coach as buyers read it, e.g. "Seater · 2+2". {@code imageUrl} is
     * the trip's cover image, or null.
     */
    record DepartureResponse(String id, String routeId, String operatorName, String operatorCode,
                             long operatorColor, String coachType, String origin, String destination,
                             LocalDateTime departsAt, int durationMinutes, long priceCents, List<String> amenities,
                             int seatsLeft, String boardingPoint, String boardingAddress, String about,
                             String imageUrl) {

        static DepartureResponse of(Departure departure) {
            EventOnSale item = departure.trip();
            BusTrip bus = item.bus();
            long price = item.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents()).orElse(0L);
            return new DepartureResponse(item.event().id().toString(),
                    BusCatalogDtos.routeId(bus.origin(), bus.destination()), item.organiser(),
                    BusCatalogDtos.operatorCode(item.organiser()), BusCatalogDtos.operatorColor(item.organiser()),
                    bus.layout().label(), bus.origin(), bus.destination(), item.event().startsAt(),
                    bus.durationMinutes(), price, bus.amenities(), departure.seatsLeft(), item.event().venue(),
                    item.page().venueDetail(), item.page().about(), item.imageUrl());
        }
    }

    /** {@code status}: available, taken, takenByFemale or takenByMale. A null in a row is the aisle. */
    record SeatMapResponse(String seatType, long priceCents, List<List<SeatResponse>> rows) {

        static SeatMapResponse of(SeatMap map) {
            return new SeatMapResponse(map.seatType(), map.priceCents(), map.rows().stream()
                    .map(row -> row.stream().map(seat -> seat == null ? null : SeatResponse.of(seat)).toList())
                    .toList());
        }
    }

    record SeatResponse(String id, String label, String detail, String status) {

        static SeatResponse of(SeatView seat) {
            return new SeatResponse(seat.id(), seat.label(), seat.detail(), seat.status());
        }
    }

    /**
     * What a booked trip adds to the event as a buyer sees it. {@code coachType} is seater, vip
     * or sleeper; {@code coachLabel} is how buyers read it. The operator is the bus company.
     */
    record BusJson(String origin, String destination, int durationMinutes, String coachType, String coachLabel,
                   List<String> amenities, String operatorCode, long operatorColor) {

        /** Null for an event that is not a bus trip. */
        static BusJson of(BusTrip trip, String organiser) {
            return trip == null ? null : new BusJson(trip.origin(), trip.destination(), trip.durationMinutes(),
                    trip.layout().code(), trip.layout().label(), trip.amenities(),
                    BusCatalogDtos.operatorCode(organiser), BusCatalogDtos.operatorColor(organiser));
        }
    }

    /** {@code phnom-penh-siem-reap}: lower case words joined by dashes. */
    static String routeId(String origin, String destination) {
        return slug(origin) + "-" + slug(destination);
    }

    private static String slug(String place) {
        // Letters, marks and digits of any script: a Khmer place name must not collapse to nothing.
        return place.strip().toLowerCase(Locale.ROOT).replaceAll("[^\\p{L}\\p{M}\\p{N}]+", "-")
                .replaceAll("^-|-$", "");
    }

    /** Two letters for the company's badge: the first letters of its first two words, else its first two letters. */
    static String operatorCode(String company) {
        String[] words = company.strip().split("\\s+");
        String code = words.length >= 2 && !words[1].isEmpty()
                ? words[0].substring(0, 1) + words[1].substring(0, 1)
                : company.strip().substring(0, Math.min(2, company.strip().length()));
        return code.isEmpty() ? "BS" : code.toUpperCase(Locale.ROOT);
    }

    static long operatorColor(String company) {
        return COLOURS[Math.floorMod(company.strip().toLowerCase(Locale.ROOT).hashCode(), COLOURS.length)];
    }
}
