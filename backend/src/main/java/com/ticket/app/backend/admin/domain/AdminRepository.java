package com.ticket.app.backend.admin.domain;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.shared.domain.EmailAddress;

/**
 * Where Pin's admins are kept. There is no sign-up: admins add other admins in the
 * admin panel, and the first one is added from the {@code pin.admin-account} settings
 * (see the backend README).
 *
 * <p>Admins added before sign-in used email addresses have none until one is given to
 * them, and removed admins are kept for the payouts they made. Neither can sign in, and
 * neither is found here.
 */
public interface AdminRepository {

    Optional<Admin> find(AdminId id);

    Optional<Admin> findByEmail(EmailAddress email);

    /** @param addedBy the admin who added them; null when added from the server settings */
    void add(Admin admin, AdminId addedBy);

    /** Marks the admin removed. @return false when there is no such admin, or they were already removed */
    boolean remove(AdminId id, AdminId removedBy, Instant now);

    /** @return false when there is no such admin, or they were removed */
    boolean changeRole(AdminId id, AdminRole role);
}
