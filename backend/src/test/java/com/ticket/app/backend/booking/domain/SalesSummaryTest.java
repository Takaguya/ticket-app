package com.ticket.app.backend.booking.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.TicketType;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.junit.jupiter.api.Test;

class SalesSummaryTest {

    private static final Instant NOW = Instant.parse("2026-11-11T22:40:00Z");

    private final Event event = Event.restore(EventId.newId(), BusinessId.newId(), "Phnom Penh Half Marathon 2026",
            LocalDateTime.of(2026, 11, 12, 5, 30), "Riverside", List.of(
                    new TicketType("5K Fun run", Money.ofCents(1200), 100),
                    new TicketType("10K", Money.ofCents(1800), 80),
                    new TicketType("21K Half marathon", Money.ofCents(2500), 40)),
            BigDecimal.valueOf(5), NOW);

    @Test
    void cancelledBookingsCountForNothingAndCommissionIsOnOnlineSalesOnly() {
        SalesSummary summary = SalesSummary.of(event, List.of(
                booking("10K", 4, 7200, SalesChannel.ONLINE, BookingStatus.OPEN),
                booking("5K Fun run", 2, 2400, SalesChannel.ONLINE, BookingStatus.CHECKED_IN),
                booking("21K Half marathon", 1, 2500, SalesChannel.ONLINE, BookingStatus.CANCELLED),
                booking("10K", 1, 1800, SalesChannel.DOOR, BookingStatus.OPEN)));

        assertThat(summary.capacity()).isEqualTo(220);
        assertThat(summary.sold()).isEqualTo(7);
        assertThat(summary.left()).isEqualTo(213);
        assertThat(summary.checkedIn()).isEqualTo(2);
        assertThat(summary.bookingCount()).isEqualTo(3);
        assertThat(summary.online()).isEqualTo(Money.ofCents(9600));
        assertThat(summary.door()).isEqualTo(Money.ofCents(1800));
        assertThat(summary.commission()).isEqualTo(Money.ofCents(480));
        assertThat(summary.revenue()).isEqualTo(Money.ofCents(11400));
        assertThat(summary.net()).isEqualTo(Money.ofCents(10920));
        assertThat(summary.byTicketType()).containsExactly(
                new SalesSummary.TicketTypeSales("5K Fun run", 100, 2, 2),
                new SalesSummary.TicketTypeSales("10K", 80, 5, 0),
                new SalesSummary.TicketTypeSales("21K Half marathon", 40, 0, 0));
        assertThat(summary.leftOf("10K")).isEqualTo(75);
        assertThat(summary.leftOf("3K")).isZero();
    }

    @Test
    void bookingsForOtherEventsAreIgnored() {
        Booking elsewhere = Booking.restore(BookingId.random(), EventId.newId(), "Bopha Keo",
                new PhoneNumber("+85549890835"), List.of(new BookingLine("10K", 2)), Money.ofCents(3600),
                PaymentMethod.CARD, SalesChannel.ONLINE, BookingStatus.OPEN, List.of(), null, NOW);

        assertThat(SalesSummary.of(event, List.of(elsewhere)).sold()).isZero();
    }

    private Booking booking(String type, int quantity, long totalCents, SalesChannel channel, BookingStatus status) {
        CheckIn checkIn = status == BookingStatus.CHECKED_IN
                ? new CheckIn(NOW, StaffId.newId(), "Dara Keo")
                : null;
        return Booking.restore(BookingId.random(), event.id(), "Bopha Keo", new PhoneNumber("+85549890835"),
                List.of(new BookingLine(type, quantity)), Money.ofCents(totalCents),
                channel == SalesChannel.DOOR ? PaymentMethod.CASH : PaymentMethod.ABA_KHQR, channel, status,
                List.of(), checkIn, NOW);
    }
}
