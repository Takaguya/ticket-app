package com.ticket.app.backend.booking.application;

import java.time.Instant;
import java.util.List;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.SaleStyle;

/**
 * How one {@link SaleStyle} sells: the rules that differ between a concert, a bus trip and a place
 * open every day. One implementation per style, chosen by {@link SalesRulesRegistry}, so the
 * services that book, sell at the door, check in and add up the numbers never ask what kind of
 * event they have.
 *
 * <p>Every method is called with the event locked, in the caller's transaction.
 */
interface SalesRules {

    SaleStyle style();

    /**
     * A purchase in the Pin app, checked against what is sold so far. Refuses what breaks the
     * style's rules: too many tickets, a missing runner, a seat that is taken, a day out of range.
     */
    PreparedSale online(Buyer buyer, OnlineOrder order, EventOnSale onSale, Instant now);

    /** A sale at the entrance, for the style's own kind of tickets. */
    PreparedSale door(Event event, DoorSale sale, Instant now);

    /** The bookings the event's sales numbers add up: all of them, or one day's. */
    List<Booking> summaryBookings(Event event);

    /**
     * Whether a scan made for {@code scanned} may also admit a ticket of {@code ticketEvent}, an
     * event that is not the scanned one. By default only the scanned event's own tickets count.
     */
    default boolean sharesGate(StaffMember staff, Event scanned, Event ticketEvent) {
        return false;
    }
}
