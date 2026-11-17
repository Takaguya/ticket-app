package com.ticket.app.backend.business.model;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.NotFoundException;
import com.ticket.app.backend.shared.model.PhoneNumber;
import org.junit.jupiter.api.Test;

class TeamTest {

    private final Business business = Business.register("Khmer Runners Club", BusinessType.EVENTS);
    private final StaffMember owner = StaffMember.owner(business, "Vannak Sok", new PhoneNumber("+85512345678"));
    private final StaffMember scanner = StaffMember.scanner(business, "Dara Keo", new PhoneNumber("+85598765432"));
    private final Team team = new Team(business, List.of(owner, scanner));

    @Test
    void aScannerCanBeRemoved() {
        assertThat(team.memberToRemove(scanner.id())).isEqualTo(scanner);
    }

    @Test
    void theOwnerCannotBeRemoved() {
        assertThatThrownBy(() -> team.memberToRemove(owner.id()))
                .isInstanceOf(BusinessRuleException.class)
                .hasMessage("The owner cannot be removed.");
    }

    @Test
    void someoneOutsideTheTeamIsNotFound() {
        assertThatThrownBy(() -> team.memberToRemove(StaffId.newId()))
                .isInstanceOf(NotFoundException.class);
    }
}
