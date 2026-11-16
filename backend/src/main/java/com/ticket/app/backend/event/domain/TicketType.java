package com.ticket.app.backend.event.domain;

import java.util.Objects;

import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Money;

/**
 * A kind of ticket for an event, e.g. "10K" at $18 with 80 for sale. A price of
 * zero means free. For a place that is open every day the quantity is a limit per
 * day, and {@link #NO_LIMIT} means there is none.
 */
public record TicketType(String name, Money price, int quantity) {

    static final int MAX_QUANTITY = 100_000;

    /** The quantity of a ticket type with no limit (a place's tickets per day). */
    public static final int NO_LIMIT = MAX_QUANTITY;
    static final Money MAX_PRICE = Money.ofCents(10_000_000);

    public TicketType {
        name = name == null ? "" : name.strip();
        if (name.isEmpty()) {
            throw BusinessRuleException.invalid("Give every ticket type a name.");
        }
        if (name.length() > 40) {
            throw BusinessRuleException.invalid("Keep ticket type names under 40 characters.");
        }
        Objects.requireNonNull(price, "price");
        if (price.isNegative() || price.compareTo(MAX_PRICE) > 0) {
            throw BusinessRuleException.invalid("Ticket prices go from $0 to $100,000.");
        }
        if (quantity < 1) {
            throw BusinessRuleException.invalid("Every ticket type needs at least 1 ticket for sale.");
        }
        if (quantity > MAX_QUANTITY) {
            throw BusinessRuleException.invalid("A ticket type can have at most 100,000 tickets.");
        }
    }

    /** Whether there is a cap on how many can be sold (per day, for a place). */
    public boolean hasLimit() {
        return quantity < NO_LIMIT;
    }
}
