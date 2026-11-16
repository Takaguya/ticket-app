package com.ticket.app.backend.booking.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.function.Function;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Money;

/**
 * What Pin owes a business now: its online bookings that no payout covers yet,
 * minus Pin's commission on them. Cancelled bookings and door sales are owed nothing.
 * Pin pays for promo codes: the gross is the tickets' full price, not what the buyer paid
 * after a discount.
 *
 * <p>When the business cancels a booking Pin has already paid it for, Pin refunds the
 * buyer and takes the business's share back from the next payout ({@code refunds}).
 * Until new sales cover those refunds, nothing is owed.
 *
 * @param refundedBookings paid-out bookings cancelled since, whose refunds this payout takes back
 */
public record PayoutDue(BusinessId businessId, List<BookingId> bookings, Money gross, Money commission,
                        List<BookingId> refundedBookings, Money refunds) {

    public PayoutDue {
        Objects.requireNonNull(businessId, "businessId");
        bookings = List.copyOf(bookings);
        Objects.requireNonNull(gross, "gross");
        Objects.requireNonNull(commission, "commission");
        refundedBookings = List.copyOf(refundedBookings);
        Objects.requireNonNull(refunds, "refunds");
    }

    /**
     * @param unpaid      the business's bookings that no payout covers yet
     * @param rateOfEvent the commission rate each event was published with
     */
    public static PayoutDue of(BusinessId businessId, Collection<Booking> unpaid,
                               Function<EventId, BigDecimal> rateOfEvent) {
        return of(businessId, unpaid, List.of(), rateOfEvent);
    }

    /**
     * @param unpaid           the business's bookings that no payout covers yet
     * @param refundsToRecover the business's paid-out bookings cancelled since, that no
     *                         payout has taken back yet
     * @param rateOfEvent      the commission rate each event was published with
     */
    public static PayoutDue of(BusinessId businessId, Collection<Booking> unpaid,
                               Collection<Booking> refundsToRecover, Function<EventId, BigDecimal> rateOfEvent) {
        List<Booking> owed = unpaid.stream()
                .filter(booking -> booking.channel() == SalesChannel.ONLINE && booking.countsAsSold())
                .toList();
        Money gross = owed.stream().map(Booking::subtotal).reduce(Money.ZERO, Money::plus);
        Money commission = owed.stream()
                .map(booking -> booking.commission(rateOfEvent.apply(booking.eventId())))
                .reduce(Money.ZERO, Money::plus);

        List<Booking> refunded = refundsToRecover.stream()
                .filter(booking -> booking.channel() == SalesChannel.ONLINE && !booking.countsAsSold())
                .toList();
        Money refunds = refunded.stream()
                .map(booking -> booking.businessShare(rateOfEvent.apply(booking.eventId())))
                .reduce(Money.ZERO, Money::plus);

        return new PayoutDue(businessId, owed.stream().map(Booking::id).toList(), gross, commission,
                refunded.stream().map(Booking::id).toList(), refunds);
    }

    /**
     * What the business is owed after Pin's commission and the refunds it takes back;
     * below zero while the refunds are more than the new sales.
     */
    public Money net() {
        return gross.minus(commission).minus(refunds);
    }

    /** New sales are waiting to be paid, and they are more than the refunds to take back. */
    public boolean isOwed() {
        return !bookings.isEmpty() && net().compareTo(Money.ZERO) > 0;
    }

    /**
     * Pays everything owed. {@code expectedNet} is the amount the admin saw and sent:
     * if more was booked or cancelled since, they are asked to check again, so the
     * payout always matches the money that really went out.
     */
    public Payout pay(Money expectedNet, Payout.PaidBy paidBy, Instant now) {
        if (!isOwed()) {
            throw BusinessRuleException.conflict("Nothing is owed to this business right now.");
        }
        if (!net().equals(expectedNet)) {
            throw BusinessRuleException.conflict("The amount owed is now " + net().toDisplayString()
                    + ". Check it and mark it as paid again.");
        }
        return new Payout(PayoutId.newId(), businessId, gross, commission, refunds, bookings.size(), now, paidBy);
    }
}
