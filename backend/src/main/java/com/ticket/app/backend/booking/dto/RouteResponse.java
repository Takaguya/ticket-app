package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.service.BusCatalogService.Route;

/** A bus route, matching the user app's BusRoute. {@code id} names the route, e.g. {@code phnom-penh-siem-reap}. */
public record RouteResponse(String id, String origin, String destination, int durationMinutes, int operatorCount,
                     int tripCount, long fromPriceCents) {

    public static RouteResponse of(Route route) {
        return new RouteResponse(BusNames.routeId(route.origin(), route.destination()), route.origin(),
                route.destination(), route.durationMinutes(), route.companies(), route.trips(),
                route.fromPriceCents());
    }
}
