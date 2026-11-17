package com.ticket.app.backend.business.model;

import java.util.Objects;

import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * A current owner or scanner of a business. Also who is signed in: controllers
 * receive it as {@code @AuthenticationPrincipal StaffMember me}.
 */
public record StaffMember(StaffId id, Business business, String name, PhoneNumber phone, StaffRole role) {

    public StaffMember {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(business, "business");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(phone, "phone");
        Objects.requireNonNull(role, "role");
    }

    public static StaffMember owner(Business business, String name, PhoneNumber phone) {
        return new StaffMember(StaffId.newId(), business, cleanName(name), phone, StaffRole.OWNER);
    }

    public static StaffMember scanner(Business business, String name, PhoneNumber phone) {
        return new StaffMember(StaffId.newId(), business, cleanName(name), phone, StaffRole.SCANNER);
    }

    public boolean isOwner() {
        return role == StaffRole.OWNER;
    }

    public BusinessId businessId() {
        return business.id();
    }

    public boolean worksFor(BusinessId businessId) {
        return business.id().equals(businessId);
    }

    private static String cleanName(String name) {
        String clean = name == null ? "" : name.strip();
        if (clean.isEmpty()) {
            throw BusinessRuleException.invalid("Enter your name.");
        }
        if (clean.length() > 80) {
            throw BusinessRuleException.invalid("Keep your name under 80 characters.");
        }
        return clean;
    }
}
