package com.ticket.app.backend.booking.model;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.shared.model.Money;

/**
 * Money Pin sent a business for online bookings: what buyers paid, minus Pin's
 * commission, minus refunds Pin made for bookings it had already paid out and the
 * business cancelled since. Door sales are paid to the business directly and never
 * appear here.
 *
 * @param refunds the business's share of the refunded bookings, taken back
 */
public record Payout(PayoutId id, BusinessId businessId, Money gross, Money commission, Money refunds,
                     int bookingCount, Instant paidAt, PaidBy paidBy) {

    /** The Pin admin who sent it, named as they were at the time. */
    public record PaidBy(UUID adminId, String name) {

        public PaidBy {
            Objects.requireNonNull(adminId, "adminId");
            Objects.requireNonNull(name, "name");
        }
    }

    public Payout {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(businessId, "businessId");
        Objects.requireNonNull(gross, "gross");
        Objects.requireNonNull(commission, "commission");
        Objects.requireNonNull(refunds, "refunds");
        Objects.requireNonNull(paidAt, "paidAt");
        Objects.requireNonNull(paidBy, "paidBy");
    }

    /** What the business received. */
    public Money net() {
        return gross.minus(commission).minus(refunds);
    }
}
