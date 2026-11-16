package com.ticket.app.backend.booking.web;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.ticket.app.backend.booking.application.PayoutService;
import com.ticket.app.backend.booking.domain.Payout;
import com.ticket.app.backend.booking.domain.PayoutDue;
import com.ticket.app.backend.business.domain.StaffMember;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** What Pin owes the owner's business for online bookings, and what it has paid. */
@RestController
class PayoutController {

    private static final int LATEST_PAYOUTS = 10;

    private final PayoutService payouts;
    private final ZoneId zone;

    PayoutController(PayoutService payouts, Clock clock) {
        this.payouts = payouts;
        this.zone = clock.getZone();
    }

    @GetMapping("/merchant/payouts")
    @PreAuthorize("hasRole('OWNER')")
    PayoutsResponse payouts(@AuthenticationPrincipal StaffMember me) {
        PayoutDue due = payouts.dueTo(me.businessId());
        return new PayoutsResponse(
                new DueResponse(due.gross().cents(), due.commission().cents(), due.refunds().cents(),
                        due.net().cents(), due.bookings().size()),
                payouts.paidTo(me.businessId(), LATEST_PAYOUTS).stream().map(this::paid).toList());
    }

    private PaidResponse paid(Payout payout) {
        return new PaidResponse(payout.id().toString(),
                LocalDateTime.ofInstant(payout.paidAt(), zone).truncatedTo(ChronoUnit.SECONDS),
                payout.gross().cents(), payout.commission().cents(), payout.refunds().cents(), payout.net().cents(),
                payout.bookingCount());
    }

    /** {@code due}: online bookings no payout covers yet. {@code paid}: the latest payouts, newest first. */
    record PayoutsResponse(DueResponse due, List<PaidResponse> paid) {
    }

    /**
     * {@code refundsCents}: the business's share of paid-out bookings it cancelled since,
     * which Pin refunded and takes back. {@code netCents} is below zero while the
     * refunds are more than the new sales.
     */
    record DueResponse(long grossCents, long commissionCents, long refundsCents, long netCents, int bookingCount) {
    }

    /** {@code paidAt} is local to Pin's time zone, without an offset. */
    record PaidResponse(String id, LocalDateTime paidAt, long grossCents, long commissionCents, long refundsCents,
                        long netCents, int bookingCount) {
    }
}
