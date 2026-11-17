package com.ticket.app.backend.booking.model;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.EventTiming;
import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.model.PhoneNumber;
import org.junit.jupiter.api.Test;

/** A place is open every day: it never ends, and its tickets are good on one visit day only. */
class PlaceVisitDayTest {

    private static final Instant NOW = Instant.parse("2026-11-16T03:00:00Z");
    private static final LocalDate TODAY = LocalDate.of(2026, 11, 16);

    /** Published long ago: its own date is only a placeholder. */
    private final Event place = Event.restore(EventId.newId(), BusinessId.newId(), "Garden City Water Park",
            LocalDateTime.of(2026, 1, 5, 0, 0), "Garden City", List.of(
                    new TicketType("Adult", Money.ofCents(1000), 300),
                    new TicketType("Child", Money.ofCents(600), TicketType.NO_LIMIT)),
            BigDecimal.valueOf(5), null, EventKind.ADMISSION);

    @Test
    void aPlaceNeverEndsSoItCanBeApprovedAndSoldAnyTime() {
        assertThat(place.timingOn(TODAY)).isEqualTo(EventTiming.TODAY);
        assertThat(place.timingOn(TODAY.plusYears(3))).isEqualTo(EventTiming.TODAY);
        place.ensureNotEndedOn(TODAY);
        place.ensureCheckInOpenOn(TODAY);

        // Not approved yet: not on sale. Approved: on sale whatever its placeholder date.
        assertThat(place.isOnSaleAt(TODAY.atStartOfDay())).isFalse();
        Event approved = place.approve(NOW, TODAY);
        assertThat(approved.isOnSaleAt(TODAY.atTime(23, 59))).isTrue();
    }

    @Test
    void aTicketTypeWithoutALimitSaysSo() {
        assertThat(place.ticketTypes().get(0).hasLimit()).isTrue();
        assertThat(place.ticketTypes().get(1).hasLimit()).isFalse();
    }

    @Test
    void aVisitDayIsFromTodayUpToSixtyTwoDaysIncludingToday() {
        place.ensureVisitable(TODAY, TODAY);
        place.ensureVisitable(TODAY.plusDays(61), TODAY);

        assertRefused(() -> place.ensureVisitable(null, TODAY), "Choose the day you are visiting.");
        assertRefused(() -> place.ensureVisitable(TODAY.minusDays(1), TODAY), "Choose today or a later day.");
        assertRefused(() -> place.ensureVisitable(TODAY.plusDays(62), TODAY),
                "Tickets can be booked up to 62 days ahead.");
    }

    @Test
    void aTicketIsGoodOnItsVisitDayOnly() {
        Booking forToday = booking(TODAY);
        forToday.ensureVisitDay(TODAY);
        assertThat(forToday.isVisitOver(TODAY)).isFalse();

        assertRefused(() -> booking(TODAY.plusDays(4)).ensureVisitDay(TODAY),
                "This ticket is for 20 Nov 2026. Check-in opens on that day.");
        Booking old = booking(TODAY.minusDays(2));
        assertRefused(() -> old.ensureVisitDay(TODAY), "This ticket was for 14 Nov 2026 and has expired.");
        assertThat(old.isVisitOver(TODAY)).isTrue();
    }

    @Test
    void aBookingThatIsNotForAPlaceHasNoVisitDay() {
        Booking plain = Booking.restore(BookingId.random(), place.id(), "Sokha Chan", new PhoneNumber("+85510222333"),
                List.of(new BookingLine("Adult", 1)), Money.ofCents(1000), PaymentMethod.CARD, SalesChannel.ONLINE,
                BookingStatus.OPEN, List.of(), null, NOW);

        assertThat(plain.visitDate()).isNull();
        plain.ensureVisitDay(TODAY.plusDays(40));
        assertThat(plain.isVisitOver(TODAY.plusDays(40))).isFalse();
    }

    private Booking booking(LocalDate visit) {
        return Booking.restore(BookingId.random(), place.id(), "Sokha Chan", new PhoneNumber("+85510222333"),
                List.of(new BookingLine("Adult", 2)), Money.ofCents(2000), PaymentMethod.CARD, SalesChannel.ONLINE,
                BookingStatus.OPEN, List.of(), null, null, null, List.of(), visit, NOW);
    }

    private static void assertRefused(Runnable call, String message) {
        assertThatThrownBy(call::run).isInstanceOf(BusinessRuleException.class).hasMessage(message);
    }
}
