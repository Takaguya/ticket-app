package com.ticket.app.backend.business.model;

import java.util.List;
import java.util.Objects;

import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.NotFoundException;

/** A business's current staff: its owner and scanners. */
public record Team(Business business, List<StaffMember> members) {

    public Team {
        Objects.requireNonNull(business, "business");
        members = List.copyOf(members);
    }

    /**
     * The member to remove, after checking they may be: they must be on this team,
     * and the owner can never be removed.
     */
    public StaffMember memberToRemove(StaffId id) {
        StaffMember member = members.stream()
                .filter(candidate -> candidate.id().equals(id))
                .findFirst()
                .orElseThrow(() -> new NotFoundException("This person is not on the team."));
        if (member.isOwner()) {
            throw BusinessRuleException.conflict("The owner cannot be removed.");
        }
        return member;
    }
}
