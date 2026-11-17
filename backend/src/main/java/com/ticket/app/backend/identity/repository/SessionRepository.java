package com.ticket.app.backend.identity.repository;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.identity.model.Session;
import com.ticket.app.backend.identity.model.TokenHash;

/** Where signed-in devices are kept, by the hash of their access token. */
public interface SessionRepository {

    void add(Session session);

    Optional<Session> find(TokenHash tokenHash);

    void remove(TokenHash tokenHash);

    /** Signs a member out on every device, e.g. when they are removed from the team. */
    void removeAllOf(StaffId staffId);

    /** Deletes sessions that expired before {@code now}. @return how many */
    int removeExpired(Instant now);
}
