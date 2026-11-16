package com.ticket.app.backend.event.domain;

import java.util.List;

import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Money;

/**
 * What the owner of an admission business fills in to publish a place: a temple park, a water
 * park, a wildlife centre. It is open every day, so it has no date: each ticket type has a price
 * and an optional limit per day.
 *
 * @param name        the place, e.g. "Garden City Water Park"
 * @param venue       the site, e.g. "Garden City"
 * @param venueDetail where it is, e.g. "Chroy Changvar, Phnom Penh"; may be empty
 * @param about       what visitors find there; may be empty
 * @param policy      refunds and changes, e.g. "Refundable up to the day before"; may be empty
 * @param tickets     1 to 6 kinds of ticket
 */
public record PlaceDraft(String name, String venue, String venueDetail, String about, String policy,
                         List<PlaceTicket> tickets) {

    /**
     * One kind of ticket of a place.
     *
     * @param description e.g. "Under 12 · ID required"; may be empty
     * @param dailyLimit  the most that can be sold for one day; null for no limit
     */
    public record PlaceTicket(String name, String description, Money price, Integer dailyLimit) {

        /** The event's ticket type: the daily limit is its quantity. */
        TicketType toTicketType() {
            if (dailyLimit != null && dailyLimit < 1) {
                throw BusinessRuleException.invalid("A daily limit is at least 1. Leave it empty for no limit.");
            }
            if (dailyLimit != null && dailyLimit >= TicketType.NO_LIMIT) {
                // That number is how "no limit" is stored, so it would silently mean no limit.
                throw BusinessRuleException.invalid("A daily limit is at most " + (TicketType.NO_LIMIT - 1)
                        + ". Leave it empty for no limit.");
            }
            if (price == null) {
                throw BusinessRuleException.invalid("Enter the price of every ticket type (0 for free).");
            }
            return new TicketType(name, price, dailyLimit == null ? TicketType.NO_LIMIT : dailyLimit);
        }
    }

    /** The place's ticket types as an event keeps them, in order. */
    public List<TicketType> toTicketTypes() {
        return tickets == null ? List.of() : tickets.stream().map(PlaceTicket::toTicketType).toList();
    }

    /** One note per ticket type, in order: what the user app shows under its name. */
    public List<String> notes() {
        return tickets == null ? List.of() : tickets.stream().map(PlaceTicket::description).toList();
    }
}
