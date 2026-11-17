package com.ticket.app.backend.identity.dto;

import com.ticket.app.backend.business.model.StaffMember;

/** A member of a business's staff, as the merchant app sees them. */
public record UserResponse(String id, String name, String phone, String role, BusinessResponse business) {

    public static UserResponse of(StaffMember member) {
        return new UserResponse(member.id().toString(), member.name(), member.phone().value(),
                member.role().code(), BusinessResponse.of(member.business()));
    }
}
