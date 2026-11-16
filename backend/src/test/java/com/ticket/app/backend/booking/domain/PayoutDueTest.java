package com.ticket.app.backend.booking.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.business.domain.JoinCode;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.business.domain.StaffRole;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.junit.jupiter.api.Test;

/** What Pin owes a business: online sales minus commission; door sales and cancellations never count. */
class PayoutDueTest {

    private static final Instant NOW = Instant.parse("2026-11-14T03:00:00Z");
    private static final BusinessId BUSINESS = BusinessId.newId();
    private static final EventId RUN = EventId.newId();
    private static final EventId CONCERT = EventId.newId();
    private static final Map<EventId, BigDecimal> RATES = Map.of(RUN, BigDecimal.valueOf(5), CONCERT,
            new BigDecimal("7.5"));
    private static final Payout.PaidBy ADMIN = new Payout.PaidBy(UUID.randomUUID(), "Moniroth Prak");
    private static final StaffMember OWNER = new StaffMember(StaffId.newId(),
            new Business(BUSINESS, "Khmer Runners Club", BusinessType.EVENTS, new JoinCode("482913"),
                    BusinessStatus.ACTIVE),
            "Vannak Sok", new PhoneNumber("+85512345678"), StaffRole.OWNER);

    private final Booking online = booking(RUN, 3600, SalesChannel.ONLINE, BookingStatus.OPEN);
    private final Booking otherEvent = booking(CONCERT, 1250, SalesChannel.ONLINE, BookingStatus.OPEN);
    private final Booking cancelled = booking(RUN, 2500, SalesChannel.ONLINE, BookingStatus.CANCELLED);
    private final Booking door = booking(RUN, 1800, SalesChannel.DOOR, BookingStatus.OPEN);
    private final PayoutDue due = PayoutDue.of(BUSINESS, List.of(online, otherEvent, cancelled, door), RATES::get);

    @Test
    void onlyOnlineBookingsThatStillCountAreOwed() {
        assertThat(due.bookings()).containsExactly(online.id(), otherEvent.id());
        assertThat(due.gross()).isEqualTo(Money.ofCents(4850));
        // 5% of $36.00 is $1.80; 7.5% of $12.50 is $0.9375, rounded to $0.94.
        assertThat(due.commission()).isEqualTo(Money.ofCents(180 + 94));
        assertThat(due.net()).isEqualTo(Money.ofCents(4850 - 274));
    }

    @Test
    void payingRecordsExactlyWhatIsOwed() {
        Payout payout = due.pay(Money.ofCents(4576), ADMIN, NOW);

        assertThat(payout.businessId()).isEqualTo(BUSINESS);
        assertThat(payout.gross()).isEqualTo(Money.ofCents(4850));
        assertThat(payout.net()).isEqualTo(Money.ofCents(4576));
        assertThat(payout.bookingCount()).isEqualTo(2);
        assertThat(payout.paidAt()).isEqualTo(NOW);
        assertThat(payout.paidBy()).isEqualTo(ADMIN);
    }

    @Test
    void refundsOfPaidOutBookingsTheBusinessCancelledComeOffTheNextPayout() {
        Booking paidThenCancelled = booking(RUN, 2000, SalesChannel.ONLINE, BookingStatus.OPEN);
        paidThenCancelled.cancel(OWNER, CancelReason.EVENT_CHANGED, NOW);

        PayoutDue withRefund = PayoutDue.of(BUSINESS, List.of(online, otherEvent), List.of(paidThenCancelled),
                RATES::get);

        // The business had received $20.00 minus 5%: $19.00 comes back off $45.76.
        assertThat(withRefund.refundedBookings()).containsExactly(paidThenCancelled.id());
        assertThat(withRefund.refunds()).isEqualTo(Money.ofCents(1900));
        assertThat(withRefund.net()).isEqualTo(Money.ofCents(4576 - 1900));
        Payout payout = withRefund.pay(Money.ofCents(2676), ADMIN, NOW);
        assertThat(payout.refunds()).isEqualTo(Money.ofCents(1900));
        assertThat(payout.net()).isEqualTo(Money.ofCents(2676));
        assertThat(payout.bookingCount()).isEqualTo(2);
    }

    @Test
    void nothingIsOwedWhileRefundsAreMoreThanNewSales() {
        Booking bigRefund = booking(RUN, 9000, SalesChannel.ONLINE, BookingStatus.OPEN);
        bigRefund.cancel(OWNER, CancelReason.BUYER_ASKED, NOW);

        PayoutDue due = PayoutDue.of(BUSINESS, List.of(online), List.of(bigRefund), RATES::get);

        assertThat(due.net()).isEqualTo(Money.ofCents(3420 - 8550));
        assertThat(due.isOwed()).isFalse();
        assertThatThrownBy(() -> due.pay(due.net(), ADMIN, NOW))
                .hasMessage("Nothing is owed to this business right now.");
    }

    @Test
    void anAmountThatChangedOrNothingOwedIsRefused() {
        assertThatThrownBy(() -> due.pay(Money.ofCents(4000), ADMIN, NOW))
                .hasMessage("The amount owed is now $45.76. Check it and mark it as paid again.");
        PayoutDue nothing = PayoutDue.of(BUSINESS, List.of(cancelled, door), RATES::get);
        assertThat(nothing.isOwed()).isFalse();
        assertThatThrownBy(() -> nothing.pay(Money.ZERO, ADMIN, NOW))
                .hasMessage("Nothing is owed to this business right now.");
    }

    private static Booking booking(EventId event, long totalCents, SalesChannel channel, BookingStatus status) {
        PaymentMethod payment = channel == SalesChannel.DOOR ? PaymentMethod.CASH : PaymentMethod.ABA_KHQR;
        return Booking.restore(BookingId.random(), event, "Bopha Keo", new PhoneNumber("+85549890835"),
                List.of(new BookingLine("5K", 1)), Money.ofCents(totalCents), payment, channel, status, List.of(),
                null, NOW);
    }
}
