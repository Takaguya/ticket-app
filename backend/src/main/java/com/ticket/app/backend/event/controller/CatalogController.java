package com.ticket.app.backend.event.controller;

import java.util.List;

import com.ticket.app.backend.event.service.CatalogService;
import com.ticket.app.backend.event.model.EventId;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.event.dto.EventListingResponse;

/** The events a signed-in buyer can book. */
@RestController
@RequestMapping("/catalog/events")
class CatalogController {

    private final CatalogService catalog;

    CatalogController(CatalogService catalog) {
        this.catalog = catalog;
    }

    /** Every event on sale, soonest first. */
    @GetMapping
    List<EventListingResponse> list() {
        return catalog.onSale().stream().map(EventListingResponse::of).toList();
    }

    /** One event on sale; 404 when it does not exist or is no longer on sale. */
    @GetMapping("/{eventId}")
    EventListingResponse one(@PathVariable String eventId) {
        return EventListingResponse.of(catalog.onSale(EventId.parse(eventId)));
    }
}
