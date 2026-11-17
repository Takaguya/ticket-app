package com.ticket.app.backend.event.model;

/**
 * How an event's tickets are sold: the one thing that changes how booking, door sales, check-in
 * and the numbers work. Every {@link EventKind} has one; the booking module has one set of rules
 * for each style, so a new kind of an existing style needs no new code there.
 */
public enum SaleStyle {

    /** Tickets by type, up to the event's capacity: a marathon, a concert, a show. */
    TICKETS,

    /** Seats chosen on a map, each held by one booking at a time: a bus trip, a screening. */
    SEATS,

    /**
     * Tickets by type for one visit day of a place that is open every day. Each ticket type has
     * a limit per day, and a ticket is good on its day only: a temple park, a water park.
     */
    DAY_PASS
}
