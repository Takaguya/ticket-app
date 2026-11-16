package com.ticket.app.backend.booking.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.business.domain.JoinCode;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.business.domain.StaffRole;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.TicketType;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.junit.jupiter.api.Test;

class BookingTest {

    private static final Instant NOW = Instant.parse("2026-11-11T22:40:00Z");
    private static final BigDecimal RATE = BigDecimal.valueOf(5);
    private static final PhoneNumber BUYER = new PhoneNumber("+85549890835");

    private final Business business = new Business(BusinessId.newId(), "Khmer Runners Club", BusinessType.EVENTS,
            new JoinCode("482913"), BusinessStatus.ACTIVE);
    private final StaffMember dara = member("Dara Keo");
    private final StaffMember sreyneang = member("Sreyneang Lim");
    private final StaffMember owner = new StaffMember(StaffId.newId(), business, "Vannak Sok",
            new PhoneNumber("+85512345678"), StaffRole.OWNER);
    private final Event marathon = Event.restore(EventId.newId(), business.id(), "Phnom Penh Half Marathon 2026",
            LocalDateTime.of(2026, 11, 12, 5, 30), "Riverside", List.of(
                    new TicketType("5K Fun run", Money.ofCents(1200), 100),
                    new TicketType("10K", Money.ofCents(1800), 80),
                    new TicketType("21K Half marathon", Money.ofCents(2500), 2)),
            RATE, NOW);

    @Test
    void aValidBookingIsAdmittedAsAWholeAndOnlyOnce() {
        Booking booking = online(BookingStatus.OPEN);

        CheckInResult first = booking.checkIn(dara, NOW);
        assertThat(first).isEqualTo(new CheckInResult.Admitted(booking));
        assertThat(booking.status()).isEqualTo(BookingStatus.CHECKED_IN);
        assertThat(booking.checkIn()).isEqualTo(new CheckIn(NOW, dara.id(), "Dara Keo"));

        // A second scan never admits, and shows the first scan.
        CheckInResult second = booking.checkIn(sreyneang, NOW.plusSeconds(60));
        assertThat(second).isInstanceOf(CheckInResult.AlreadyUsed.class);
        assertThat(booking.checkIn().staffName()).isEqualTo("Dara Keo");
        assertThat(booking.checkIn().at()).isEqualTo(NOW);
    }

    @Test
    void aCancelledBookingIsNeverAdmitted() {
        Booking booking = online(BookingStatus.CANCELLED);

        assertThat(booking.checkIn(dara, NOW)).isInstanceOf(CheckInResult.Cancelled.class);
        assertThat(booking.status()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(booking.checkIn()).isNull();
    }

    @Test
    void theBusinessCancelsAnOpenBookingOnceAndItIsNeverAdmitted() {
        Booking booking = online(BookingStatus.OPEN);

        assertThat(booking.cancel(owner, CancelReason.EVENT_CHANGED, NOW)).isTrue();
        assertThat(booking.status()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(booking.cancellation())
                .isEqualTo(new Cancellation(NOW, owner.id(), "Vannak Sok", CancelReason.EVENT_CHANGED));
        assertThat(booking.countsAsSold()).isFalse();
        assertThat(booking.checkIn(dara, NOW)).isInstanceOf(CheckInResult.Cancelled.class);

        // Sent again: nothing changes, the first reason stays.
        assertThat(booking.cancel(owner, CancelReason.OTHER, NOW.plusSeconds(60))).isFalse();
        assertThat(booking.cancellation().reason()).isEqualTo(CancelReason.EVENT_CHANGED);
        assertThat(booking.cancellation().at()).isEqualTo(NOW);
    }

    @Test
    void aCheckedInBookingCannotBeCancelledAndAReasonIsNeeded() {
        assertRefused(() -> online(BookingStatus.CHECKED_IN).cancel(owner, CancelReason.BUYER_ASKED, NOW),
                "This booking is checked in, so it can't be cancelled.");
        assertRefused(() -> online(BookingStatus.OPEN).cancel(owner, null, NOW),
                "Choose why the booking is cancelled.");
        assertRefused(() -> CancelReason.fromCode("bored"), "Choose why the booking is cancelled.");
        assertThat(CancelReason.fromCode("soldByMistake")).isEqualTo(CancelReason.SOLD_BY_MISTAKE);
    }

    @Test
    void pinRefundsOnlineBookingsTheBusinessCancelsAndTheBusinessPaysBackDoorSales() {
        Booking online = online(BookingStatus.OPEN);
        Booking door = doorSale(List.of(new BookingLine("10K", 2)));
        assertThat(online.refund()).isEqualTo(Money.ZERO);

        online.cancel(owner, CancelReason.BUYER_ASKED, NOW);
        door.cancel(owner, CancelReason.SOLD_BY_MISTAKE, NOW);

        assertThat(online.refund()).isEqualTo(Money.ofCents(7200));
        assertThat(door.refund()).isEqualTo(Money.ZERO);
        // Cancelled before cancellations were recorded: what was refunded is not known.
        assertThat(online(BookingStatus.CANCELLED).refund()).isEqualTo(Money.ZERO);
        // $72.00 minus 5% commission.
        assertThat(online.businessShare(RATE)).isEqualTo(Money.ofCents(6840));
    }

    @Test
    void bookingIdsCanBeTypedAsTheEightDigits() {
        assertThat(BookingId.parse("48213377")).contains(new BookingId("TK48213377"));
        assertThat(BookingId.parse(" tk48213377 ")).contains(new BookingId("TK48213377"));
        assertThat(BookingId.parse("TK4821337")).isEmpty();
        assertThat(BookingId.parse("hello")).isEmpty();
        assertThat(BookingId.random().value()).matches("TK[0-9]{8}");
    }

    @Test
    void commissionIsOnlyOnOnlineSalesThatCount() {
        assertThat(online(BookingStatus.OPEN).commission(RATE)).isEqualTo(Money.ofCents(360));
        assertThat(online(BookingStatus.CANCELLED).commission(RATE)).isEqualTo(Money.ZERO);
        assertThat(doorSale(List.of(new BookingLine("10K", 4))).commission(RATE)).isEqualTo(Money.ZERO);
    }

    @Test
    void aDoorSaleIsPricedFromTheEvent() {
        Booking sale = doorSale(List.of(new BookingLine("5K Fun run", 1), new BookingLine("10K", 2)));

        assertThat(sale.total()).isEqualTo(Money.ofCents(4800));
        assertThat(sale.channel()).isEqualTo(SalesChannel.DOOR);
        assertThat(sale.status()).isEqualTo(BookingStatus.OPEN);
        assertThat(sale.buyerName()).isEqualTo(Booking.WALK_IN_GUEST);
        assertThat(sale.ticketCount()).isEqualTo(3);
        assertThat(sale.summary()).isEqualTo("1× 5K Fun run, 2× 10K");
    }

    @Test
    void aDoorSaleIsRefusedWhenTheRulesSayNo() {
        SalesSummary nothingSold = SalesSummary.of(marathon, List.of());

        assertRefused(() -> Booking.soldAtDoor(BookingId.random(), marathon, List.of(new BookingLine("10K", 1)),
                BUYER, PaymentMethod.CARD, nothingSold, NOW), "Door sales are paid by cash or KHQR.");
        assertRefused(() -> doorSale(List.of()), "Choose at least one ticket.");
        assertRefused(() -> doorSale(List.of(new BookingLine("5K Fun run", 5), new BookingLine("10K", 4))),
                "Maximum 8 tickets per sale.");
        assertRefused(() -> doorSale(List.of(new BookingLine("3K", 1))), "This event has no ticket type called 3K.");
        assertRefused(() -> doorSale(List.of(new BookingLine("21K Half marathon", 3))),
                "Only 2 left for 21K Half marathon.");
    }

    @Test
    void nothingIsSoldOnceTheEventIsFull() {
        Event small = Event.restore(EventId.newId(), business.id(), "Small Run", LocalDateTime.of(2026, 11, 12, 6, 0),
                "Riverside", List.of(new TicketType("5K", Money.ofCents(1000), 3)), RATE, NOW);
        Booking full = Booking.restore(BookingId.random(), small.id(), "Bopha Keo", BUYER,
                List.of(new BookingLine("5K", 3)), Money.ofCents(3000), PaymentMethod.ABA_KHQR, SalesChannel.ONLINE,
                BookingStatus.OPEN, List.of(), null, NOW);

        assertRefused(() -> Booking.soldAtDoor(BookingId.random(), small, List.of(new BookingLine("5K", 1)), BUYER,
                PaymentMethod.CASH, SalesSummary.of(small, List.of(full)), NOW), "Sold out. No tickets left to sell.");
    }

    @Test
    void searchMatchesNameBookingIdOrThreeDigitsOfThePhone() {
        Booking booking = Booking.restore(new BookingId("TK48213377"), marathon.id(), "Bopha Keo", BUYER,
                List.of(new BookingLine("10K", 4)), Money.ofCents(7200), PaymentMethod.CARD, SalesChannel.ONLINE,
                BookingStatus.OPEN, List.of(), null, NOW);

        assertThat(new BookingSearch("bopha", null).matches(booking)).isTrue();
        assertThat(new BookingSearch("8213", null).matches(booking)).isTrue();
        assertThat(new BookingSearch("049 890", null).matches(booking)).isTrue();
        assertThat(new BookingSearch("999", null).matches(booking)).isFalse();
        assertThat(new BookingSearch("", BookingStatus.CANCELLED).matches(booking)).isFalse();
        assertThat(BookingSearch.ALL.matches(booking)).isTrue();
    }

    private Booking online(BookingStatus status) {
        CheckIn checkIn = status == BookingStatus.CHECKED_IN ? new CheckIn(NOW, dara.id(), dara.name()) : null;
        return Booking.restore(BookingId.random(), marathon.id(), "Bopha Keo", BUYER,
                List.of(new BookingLine("10K", 4)), Money.ofCents(7200), PaymentMethod.ABA_KHQR, SalesChannel.ONLINE,
                status, List.of("S", "M", "L", "XS"), checkIn, NOW);
    }

    private Booking doorSale(List<BookingLine> lines) {
        return Booking.soldAtDoor(BookingId.random(), marathon, lines, BUYER, PaymentMethod.CASH,
                SalesSummary.of(marathon, List.of()), NOW);
    }

    private StaffMember member(String name) {
        return new StaffMember(StaffId.newId(), business, name, new PhoneNumber("+85598765432"), StaffRole.SCANNER);
    }

    private static void assertRefused(Runnable action, String message) {
        assertThatThrownBy(action::run).isInstanceOf(BusinessRuleException.class).hasMessage(message);
    }
}
