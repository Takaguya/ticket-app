package com.ticket.app.backend.event.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Money;
import org.junit.jupiter.api.Test;

class EventTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 11, 12);
    private static final BusinessId BUSINESS = BusinessId.newId();
    private static final BigDecimal RATE = BigDecimal.valueOf(5);

    @Test
    void aPublishedEventHasTheSumOfItsTicketTypesAsCapacity() {
        Event event = publish("Kampot River Run 2026", TODAY.plusDays(8).atTime(6, 0),
                List.of(type("5K", 1000, 150), type("10K", 0, 50)));

        assertThat(event.capacity()).isEqualTo(200);
        assertThat(event.belongsTo(BUSINESS)).isTrue();
        assertThat(event.commissionRate()).isEqualTo(RATE);
        assertThat(event.ticketType("10K")).map(TicketType::price).contains(Money.ZERO);
    }

    @Test
    void anEventCanBeOnTheSameDay() {
        assertThatCode(() -> publish("Night Run", TODAY.atTime(18, 30), List.of(type("5K", 1000, 10))))
                .doesNotThrowAnyException();
    }

    @Test
    void publishingRefusesWhatTheRulesDoNotAllow() {
        List<TicketType> oneType = List.of(type("5K", 1000, 10));

        assertRefused(() -> publish("Yesterday Run", TODAY.minusDays(1).atTime(6, 0), oneType),
                "The event date cannot be in the past.");
        assertRefused(() -> publish("Go", TODAY.atTime(6, 0), oneType),
                "Give the event a name of at least 3 characters.");
        assertRefused(() -> publish("No Types Run", TODAY.atTime(6, 0), List.of()),
                "Add at least one ticket type.");
        assertRefused(() -> publish("Seven Types Run", TODAY.atTime(6, 0),
                        Collections.nCopies(7, type("5K", 1000, 10))),
                "An event can have at most 6 ticket types.");
        assertRefused(() -> publish("Twin Types Run", TODAY.atTime(6, 0), List.of(type("5K", 1000, 10),
                        type("5k", 2000, 10))),
                "Each ticket type needs a different name.");
    }

    @Test
    void ticketTypesNeedANameAPriceOfZeroOrMoreAndAtLeastOneTicket() {
        assertRefused(() -> type(" ", 1000, 10), "Give every ticket type a name.");
        assertRefused(() -> type("5K", -1, 10), "Ticket prices go from $0 to $100,000.");
        assertRefused(() -> type("5K", 1000, 0), "Every ticket type needs at least 1 ticket for sale.");
    }

    @Test
    void checkInIsOnlyOpenOnTheDayOfTheEvent() {
        Event event = publish("Phnom Penh Half Marathon", TODAY.atTime(5, 30), List.of(type("10K", 1800, 80)));

        assertThat(event.timingOn(TODAY)).isEqualTo(EventTiming.TODAY);
        assertThatCode(() -> event.ensureCheckInOpenOn(TODAY)).doesNotThrowAnyException();
        assertRefused(() -> event.ensureCheckInOpenOn(TODAY.minusDays(1)), "Check-in opens on the day of the event.");
        assertRefused(() -> event.ensureCheckInOpenOn(TODAY.plusDays(1)), "The event has ended.");
    }

    private static Event publish(String name, LocalDateTime startsAt, List<TicketType> types) {
        return Event.publish(BUSINESS, new EventDraft(name, startsAt, "Riverside, Sisowath Quay", types), TODAY, RATE);
    }

    private static TicketType type(String name, long priceCents, int quantity) {
        return new TicketType(name, Money.ofCents(priceCents), quantity);
    }

    private static void assertRefused(Runnable action, String message) {
        assertThatThrownBy(action::run).isInstanceOf(BusinessRuleException.class).hasMessage(message);
    }
}
