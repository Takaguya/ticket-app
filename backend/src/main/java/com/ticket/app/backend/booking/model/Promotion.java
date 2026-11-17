package com.ticket.app.backend.booking.model;

import java.math.BigDecimal;
import java.util.Locale;

import com.ticket.app.backend.shared.model.Money;

/**
 * A promo code, e.g. {@code D2D10} for 10% off. A percentage, a fixed amount or both
 * come off, never more than the order costs.
 *
 * @param title        e.g. "10% off tickets"
 * @param description  e.g. "Any category"
 * @param minimumSpend the order must cost at least this much
 */
public record Promotion(String code, String title, String description, int percentOff, Money amountOff,
                        Money minimumSpend) {

    /** Codes are not case sensitive; spaces around what was typed are ignored. */
    public boolean matches(String typed) {
        return typed != null && typed.strip().toUpperCase(Locale.ROOT).equals(code);
    }

    public boolean appliesTo(Money subtotal) {
        return subtotal.cents() > 0 && subtotal.compareTo(minimumSpend) >= 0;
    }

    /** How much comes off an order of {@code subtotal}: nothing when the code does not apply. */
    public Money discountOn(Money subtotal) {
        if (!appliesTo(subtotal)) {
            return Money.ZERO;
        }
        Money off = subtotal.percent(BigDecimal.valueOf(percentOff)).plus(amountOff);
        return off.compareTo(subtotal) > 0 ? subtotal : off;
    }
}
