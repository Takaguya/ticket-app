package com.ticket.app.backend.event.service;

import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventImage;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.Screening;
import com.ticket.app.backend.event.model.SeatLayout;

/**
 * An event as the user app shows it: the event, its page, the name of the business that
 * organises it and, for a bus trip or a cinema screening, its details.
 *
 * @param bus          null unless the event is a bus trip
 * @param screening    null unless the event is a cinema screening
 * @param imageVersion null unless the event has a cover image; see {@link EventImage#version()}
 */
public record EventOnSale(Event event, EventPage page, String organiser, BusTrip bus, Screening screening,
                          Long imageVersion) {

    /** Where the cover image is, to put in JSON; null when there is none. */
    public String imageUrl() {
        return EventImage.urlOf(event.id(), imageVersion);
    }

    /** The seats of a bus trip or a screening; null for any other event. */
    public SeatLayout layout() {
        if (bus != null) {
            return bus.layout();
        }
        return screening == null ? null : screening.layout();
    }
}
