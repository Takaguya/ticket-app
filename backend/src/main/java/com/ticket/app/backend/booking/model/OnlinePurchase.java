package com.ticket.app.backend.booking.model;

import java.util.Objects;

import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.shared.model.Money;

/**
 * What only a booking made in the Pin app has: who bought it, the promo code it used
 * and the discount it got, and the runner of a race.
 *
 * @param promoCode the code as on offer (upper case); null when none was used
 * @param runner    null unless the event is a race
 */
public record OnlinePurchase(BuyerId buyer, String promoCode, Money discount, Runner runner) {

    public OnlinePurchase {
        Objects.requireNonNull(buyer, "buyer");
        Objects.requireNonNull(discount, "discount");
        if (promoCode == null && discount.cents() != 0) {
            throw new IllegalArgumentException("A discount needs a promo code");
        }
    }
}
