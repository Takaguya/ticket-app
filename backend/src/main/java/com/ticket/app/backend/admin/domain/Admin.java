package com.ticket.app.backend.admin.domain;

import java.util.Objects;

import com.ticket.app.backend.booking.domain.Payout;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.EmailAddress;
import com.ticket.app.backend.shared.domain.Ids;

/**
 * A Pin staff member who runs the back office: approves businesses and events,
 * suspends businesses and pays them. Also who is signed in to the admin panel:
 * controllers receive it as {@code @AuthenticationPrincipal Admin me}. Admins sign in
 * with their email address and a password. Super admins also add and remove admins.
 */
public record Admin(AdminId id, String name, EmailAddress email, AdminRole role) {

    /** As the {@code admins} table allows. */
    public static final int MAX_NAME_LENGTH = 80;

    public Admin {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(email, "email");
        Objects.requireNonNull(role, "role");
    }

    /** A new admin, not saved yet. */
    public static Admin create(String name, EmailAddress email, AdminRole role) {
        String trimmed = name == null ? "" : name.strip();
        if (trimmed.isEmpty() || trimmed.length() > MAX_NAME_LENGTH) {
            throw BusinessRuleException.invalid("An admin's name needs 1 to " + MAX_NAME_LENGTH + " characters.");
        }
        return new Admin(new AdminId(Ids.newId()), trimmed, email, role);
    }

    public boolean managesAdmins() {
        return role.managesAdmins();
    }

    /** This admin as the sender of a payout. */
    public Payout.PaidBy asPayer() {
        return new Payout.PaidBy(id.value(), name);
    }
}
