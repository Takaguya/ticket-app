package com.ticket.app.backend.identity.domain;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.admin.domain.AdminId;

/** Where signed-in admin browsers are kept, by the hash of their access token. */
public interface AdminSessionRepository {

    void add(AdminSession session);

    Optional<AdminSession> find(TokenHash tokenHash);

    void remove(TokenHash tokenHash);

    /** Signs the admin out of every browser. */
    void removeAllFor(AdminId adminId);

    /** Signs the admin out of every browser but the one with this session. */
    void removeAllForExcept(AdminId adminId, TokenHash keep);

    /** Deletes sessions that expired before {@code now}. @return how many */
    int removeExpired(Instant now);
}
