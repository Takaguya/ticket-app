package com.ticket.app.backend.business.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ticket.app.backend.shared.domain.BusinessRuleException;
import org.junit.jupiter.api.Test;

/** A business sells once approved; an admin can suspend and reinstate it. */
class BusinessStatusTest {

    private final Business pending = Business.register("Kep Crab Market", BusinessType.EVENTS);

    @Test
    void aNewBusinessWaitsForApprovalAndMayPrepareEventsButNotSell() {
        assertThat(pending.status()).isEqualTo(BusinessStatus.PENDING);
        assertThatCode(pending::ensureCanPublish).doesNotThrowAnyException();
        assertThatThrownBy(pending::ensureCanSell)
                .isInstanceOf(BusinessRuleException.class)
                .hasMessage("Pin is still reviewing your business. You can sell tickets once it is approved.");
    }

    @Test
    void approvedItSells() {
        Business active = pending.approve();

        assertThat(active.status()).isEqualTo(BusinessStatus.ACTIVE);
        assertThat(active.isActive()).isTrue();
        assertThatCode(active::ensureCanSell).doesNotThrowAnyException();
        assertThat(active.id()).isEqualTo(pending.id());
        assertThat(active.joinCode()).isEqualTo(pending.joinCode());
    }

    @Test
    void suspendedItNeitherSellsNorPublishesUntilReinstated() {
        Business suspended = pending.approve().suspend();

        assertThatThrownBy(suspended::ensureCanSell)
                .hasMessage("Pin has suspended your business. Contact Pin to sell tickets again.");
        assertThatThrownBy(suspended::ensureCanPublish)
                .hasMessage("Pin has suspended your business. Contact Pin to publish events again.");
        assertThat(suspended.reinstate().status()).isEqualTo(BusinessStatus.ACTIVE);
    }

    @Test
    void eachChangeOnlyFromTheRightStatus() {
        Business active = pending.approve();
        Business suspended = active.suspend();

        assertThatThrownBy(active::approve).hasMessage("Kep Crab Market is already approved.");
        assertThatThrownBy(suspended::approve).hasMessage("Kep Crab Market is already suspended.");
        assertThatThrownBy(pending::suspend).hasMessage("Kep Crab Market is not approved yet.");
        assertThatThrownBy(suspended::suspend).hasMessage("Kep Crab Market is already suspended.");
        assertThatThrownBy(active::reinstate).hasMessage("Kep Crab Market is not suspended.");
        assertThatThrownBy(pending::reinstate).hasMessage("Kep Crab Market is not suspended.");
    }
}
