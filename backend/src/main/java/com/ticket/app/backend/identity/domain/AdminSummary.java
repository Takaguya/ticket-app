package com.ticket.app.backend.identity.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.admin.domain.AdminRole;
import com.ticket.app.backend.shared.domain.EmailAddress;

/**
 * One admin as the Admins page lists them: who they are, when and by whom they were
 * added, and whether they can sign in with a password of their own yet.
 *
 * @param addedBy the name of the admin who added them; null when added from the server
 *                settings or the demo data
 */
public record AdminSummary(AdminId id, String name, EmailAddress email, AdminRole role, Instant addedAt,
                           String addedBy, PasswordState password) {

    public enum PasswordState {
        /** Signs in with a password they chose. */
        OWN,
        /** Has the temporary password they were given: must choose their own at sign-in. */
        TEMPORARY,
        /** Has no password, so cannot sign in. */
        NONE
    }

    public AdminSummary {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(email, "email");
        Objects.requireNonNull(role, "role");
        Objects.requireNonNull(addedAt, "addedAt");
        Objects.requireNonNull(password, "password");
    }

    public Optional<String> addedByIfKnown() {
        return Optional.ofNullable(addedBy);
    }
}
