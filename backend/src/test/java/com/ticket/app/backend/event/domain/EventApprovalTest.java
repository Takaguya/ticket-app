package com.ticket.app.backend.event.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.shared.domain.Money;
import org.junit.jupiter.api.Test;

/** A published event goes on sale once a Pin admin approves it. */
class EventApprovalTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 11, 14);
    private static final Instant NOW = Instant.parse("2026-11-14T03:00:00Z");

    private final Event published = Event.publish(BusinessId.newId(), new EventDraft("Temple Run 2026",
                    TODAY.plusDays(5).atTime(6, 0), "Angkor Wat",
                    List.of(new TicketType("5K", Money.ofCents(1000), 100))),
            TODAY, BigDecimal.valueOf(5));

    @Test
    void aPublishedEventWaitsForApprovalAndCannotSell() {
        assertThat(published.isApproved()).isFalse();
        assertThat(published.approvedAt()).isEmpty();
        assertThatThrownBy(published::ensureApproved)
                .hasMessage("Pin is still reviewing this event. You can sell tickets once it is approved.");
    }

    @Test
    void approvedItCanSell() {
        Event approved = published.approve(NOW, TODAY);

        assertThat(approved.isApproved()).isTrue();
        assertThat(approved.approvedAt()).contains(NOW);
        assertThat(approved).isEqualTo(published);
        assertThatCode(approved::ensureApproved).doesNotThrowAnyException();
    }

    @Test
    void itIsApprovedOnceAndNeverAfterItsDay() {
        Event approved = published.approve(NOW, TODAY);

        assertThatThrownBy(() -> approved.approve(NOW, TODAY)).hasMessage("Temple Run 2026 is already approved.");
        assertThatThrownBy(() -> published.approve(NOW, TODAY.plusDays(6))).hasMessage("Temple Run 2026 has ended.");
        assertThatCode(() -> published.approve(NOW, TODAY.plusDays(5))).doesNotThrowAnyException();
    }
}
