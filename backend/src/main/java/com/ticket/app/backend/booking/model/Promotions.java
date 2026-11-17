package com.ticket.app.backend.booking.model;

import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.shared.model.Money;

/** The promo codes on offer, the same as the user app's prototype. */
public final class Promotions {

    public static final List<Promotion> ON_OFFER = List.of(
            new Promotion("D2D10", "10% off tickets", "Any category", 10, Money.ZERO, Money.ZERO),
            new Promotion("FIRST", "$2 off", "Orders of $5 or more", 0, Money.ofCents(200), Money.ofCents(500)));

    private Promotions() {
    }

    /** The offer a typed code names, ignoring capitals and spaces around it. */
    public static Optional<Promotion> find(String typed) {
        return ON_OFFER.stream().filter(promotion -> promotion.matches(typed)).findFirst();
    }
}
