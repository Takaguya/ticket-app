package com.ticket.app.backend.event.controller;

import java.util.List;
import java.util.Map;

import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.event.service.EventImageService;
import com.ticket.app.backend.event.service.EventService;
import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.Screening;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.event.dto.EventResponse;
import com.ticket.app.backend.event.dto.PublishBusTripRequest;
import com.ticket.app.backend.event.dto.PublishEventRequest;
import com.ticket.app.backend.event.dto.PublishPlaceRequest;
import com.ticket.app.backend.event.dto.PublishScreeningRequest;

/** The business's events. Everyone on the team sees them; only the owner publishes. */
@RestController
@RequestMapping("/merchant/events")
class EventController {

    private final EventService events;
    private final EventImageService images;

    EventController(EventService events, EventImageService images) {
        this.events = events;
        this.images = images;
    }

    /** All events of the business, earliest first. A bus company's are its trips. */
    @GetMapping
    List<EventResponse> list(@AuthenticationPrincipal StaffMember me) {
        List<Event> mine = events.eventsOf(me);
        Map<EventId, BusTrip> trips = events.busTripsOf(mine);
        Map<EventId, Screening> screenings = events.screeningsOf(mine);
        Map<EventId, Long> imageVersions = images.versionsOf(mine.stream().map(Event::id).toList());
        return mine.stream()
                .map(event -> EventResponse.of(event, trips.get(event.id()), screenings.get(event.id()))
                        .withImageVersion(imageVersions.get(event.id())))
                .toList();
    }

    @GetMapping("/{eventId}")
    EventResponse one(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId) {
        return describe(events.eventOf(me, EventId.parse(eventId)));
    }

    /** The event with its bus or film details and its image, when it has them. */
    private EventResponse describe(Event event) {
        return EventResponse.of(event, events.busTrip(event.id()).orElse(null),
                events.screening(event.id()).orElse(null))
                .withImageVersion(images.versionsOf(List.of(event.id())).get(event.id()));
    }

    /** Publishes an event. It can be booked once a Pin admin approves it. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('OWNER')")
    EventResponse publish(@AuthenticationPrincipal StaffMember me, @Valid @RequestBody PublishEventRequest request) {
        return EventResponse.of(events.publish(me, request.toDraft()));
    }

    /** Publishes a bus trip (bus companies only). It can be booked once a Pin admin approves it. */
    @PostMapping("/bus-trips")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('OWNER')")
    EventResponse publishBusTrip(@AuthenticationPrincipal StaffMember me,
                                 @Valid @RequestBody PublishBusTripRequest request) {
        return describe(events.publishBusTrip(me, request.toDraft()));
    }

    /** Publishes a place that is open every day (admission businesses only). It can be booked once a Pin admin approves it. */
    @PostMapping("/places")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('OWNER')")
    EventResponse publishPlace(@AuthenticationPrincipal StaffMember me,
                               @Valid @RequestBody PublishPlaceRequest request) {
        return describe(events.publishPlace(me, request.toDraft()));
    }

    /** Publishes a cinema screening (cinemas only). It can be booked once a Pin admin approves it. */
    @PostMapping("/screenings")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('OWNER')")
    EventResponse publishScreening(@AuthenticationPrincipal StaffMember me,
                                   @Valid @RequestBody PublishScreeningRequest request) {
        return describe(events.publishScreening(me, request.toDraft()));
    }
}
