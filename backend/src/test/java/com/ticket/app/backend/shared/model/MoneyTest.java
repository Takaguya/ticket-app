package com.ticket.app.backend.shared.model;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MoneyTest {

    @Test
    void amountsAreWrittenForPeopleWithThousandsSeparators() {
        assertThat(Money.ofCents(223250).toDisplayString()).isEqualTo("$2,232.50");
        assertThat(Money.ofCents(5).toDisplayString()).isEqualTo("$0.05");
        assertThat(Money.ofCents(-150).toDisplayString()).isEqualTo("-$1.50");
        assertThat(Money.ofCents(223250).toPlainString()).isEqualTo("2232.50");
    }
}
