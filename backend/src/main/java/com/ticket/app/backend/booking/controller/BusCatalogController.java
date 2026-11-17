package com.ticket.app.backend.booking.controller;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;

import com.ticket.app.backend.booking.service.BusCatalogService;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.booking.dto.DepartureResponse;
import com.ticket.app.backend.booking.dto.RouteResponse;
import com.ticket.app.backend.booking.dto.SeatMapResponse;

/** The bus trips a signed-in buyer can book: routes, the trips of a day and a trip's seats. */
@RestController
@RequestMapping("/catalog/bus")
class BusCatalogController {

    private final BusCatalogService buses;

    BusCatalogController(BusCatalogService buses) {
        this.buses = buses;
    }

    /** Every route with a trip on sale, the busiest first. */
    @GetMapping("/routes")
    List<RouteResponse> routes() {
        return buses.routes().stream().map(RouteResponse::of).toList();
    }

    /**
     * The trips from one place to another that have not left yet, earliest first.
     *
     * @param date a day such as {@code 2026-11-28}; all days when left out
     */
    @GetMapping("/departures")
    List<DepartureResponse> departures(@RequestParam String origin, @RequestParam String destination,
                                       @RequestParam(required = false) String date) {
        return buses.departures(origin, destination, day(date)).stream().map(DepartureResponse::of).toList();
    }

    /** The trip's seats and which are taken; 404 when it is not a bus trip on sale. */
    @GetMapping("/departures/{tripId}/seats")
    SeatMapResponse seats(@PathVariable String tripId) {
        return SeatMapResponse.of(buses.seatMap(EventId.parse(tripId)));
    }

    private static LocalDate day(String date) {
        if (date == null || date.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(date.strip());
        } catch (DateTimeParseException e) {
            throw BusinessRuleException.invalid("Write the day like 2026-11-28.");
        }
    }
}
