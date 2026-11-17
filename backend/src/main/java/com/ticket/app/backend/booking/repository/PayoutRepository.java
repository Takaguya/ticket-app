package com.ticket.app.backend.booking.repository;

import java.time.Instant;
import java.util.List;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.Payout;

/** Where payouts are kept. A booking belongs to at most one payout. */
public interface PayoutRepository {

    /**
     * Saves the payout, marks its bookings as paid by it, and the refunded bookings as
     * taken back by it.
     *
     * @throws IllegalStateException if one of the bookings was paid out, or one of the
     *                               refunds taken back, already; the caller locks the
     *                               business, so this never happens
     */
    void add(Payout payout, List<BookingId> bookings, List<BookingId> refundedBookings);

    /** The business's payouts, newest first. */
    List<Payout> findByBusiness(BusinessId businessId, int limit);

    /** Every business's payouts made from {@code from} until just before {@code until}, newest first. */
    List<Payout> findPaidBetween(Instant from, Instant until);
}
