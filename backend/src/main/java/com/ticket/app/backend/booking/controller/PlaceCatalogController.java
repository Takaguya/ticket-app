package com.ticket.app.backend.booking.controller;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;

import com.ticket.app.backend.booking.service.PlaceCatalogService;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.booking.dto.AvailabilityResponse;
import com.ticket.app.backend.booking.dto.PlaceResponse;

/** The places a signed-in buyer can visit: temple parks, water parks, wildlife centres, open every day. */
@RestController
@RequestMapping("/catalog/places")
class PlaceCatalogController {

    private final PlaceCatalogService places;

    PlaceCatalogController(PlaceCatalogService places) {
        this.places = places;
    }

    /** Every place on sale. */
    @GetMapping
    List<PlaceResponse> list() {
        return places.places().stream().map(PlaceResponse::of).toList();
    }

    /** One place; 404 when it does not exist, is not a place or is no longer on sale. */
    @GetMapping("/{placeId}")
    PlaceResponse one(@PathVariable String placeId) {
        return PlaceResponse.of(places.place(EventId.parse(placeId)));
    }

    /**
     * What is left of each ticket type's daily limit on a day, such as {@code 2026-11-28}; 400
     * for a day before today or too far ahead.
     */
    @GetMapping("/{placeId}/availability")
    AvailabilityResponse availability(@PathVariable String placeId, @RequestParam String date) {
        LocalDate day = day(date);
        return AvailabilityResponse.of(day, places.availability(EventId.parse(placeId), day));
    }

    private static LocalDate day(String date) {
        try {
            return LocalDate.parse(date.strip());
        } catch (DateTimeParseException e) {
            throw BusinessRuleException.invalid("Write the day like 2026-11-28.");
        }
    }
}
