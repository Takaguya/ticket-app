package com.ticket.app.backend.shared.model;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Locale;

/**
 * An amount in whole US cents ({@code 1250} is $12.50), so sums and commission
 * never pick up floating-point error.
 */
public record Money(long cents) implements Comparable<Money> {

    public static final Money ZERO = new Money(0);

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);

    public static Money ofCents(long cents) {
        return new Money(cents);
    }

    public Money plus(Money other) {
        return new Money(Math.addExact(cents, other.cents));
    }

    public Money minus(Money other) {
        return new Money(Math.subtractExact(cents, other.cents));
    }

    public Money times(int count) {
        return new Money(Math.multiplyExact(cents, count));
    }

    /** {@code rate} percent of this amount, rounded to the nearest cent (halves up). */
    public Money percent(BigDecimal rate) {
        BigDecimal share = BigDecimal.valueOf(cents).multiply(rate).divide(HUNDRED, 0, RoundingMode.HALF_UP);
        return new Money(share.longValueExact());
    }

    public boolean isNegative() {
        return cents < 0;
    }

    @Override
    public int compareTo(Money other) {
        return Long.compare(cents, other.cents);
    }

    /** {@code 12.50}: no currency sign, for files and logs. */
    public String toPlainString() {
        return BigDecimal.valueOf(cents).movePointLeft(2).toPlainString();
    }

    /** {@code $2,232.50}: as written in messages for people. */
    public String toDisplayString() {
        String amount = String.format(Locale.US, "%,.2f", BigDecimal.valueOf(Math.abs(cents)).movePointLeft(2));
        return (cents < 0 ? "-$" : "$") + amount;
    }
}
