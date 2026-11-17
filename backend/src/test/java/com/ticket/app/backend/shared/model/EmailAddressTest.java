package com.ticket.app.backend.shared.model;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class EmailAddressTest {

    @Test
    void anAddressIsKeptInLowerCaseWithoutSpaces() {
        assertThat(EmailAddress.of("  Moniroth@PIN.Example ").value()).isEqualTo("moniroth@pin.example");
    }

    @Test
    void anythingThatIsNotShapedLikeAnAddressIsRefused() {
        for (String typed : new String[] {null, "", "moniroth", "moniroth@pin", "@pin.example", "mo niroth@pin.example",
                "a@b@pin.example", "x".repeat(250) + "@pin.example"}) {
            assertThatThrownBy(() -> EmailAddress.of(typed))
                    .as(typed)
                    .isInstanceOf(BusinessRuleException.class)
                    .hasMessage("Enter a valid email address.");
        }
    }
}
