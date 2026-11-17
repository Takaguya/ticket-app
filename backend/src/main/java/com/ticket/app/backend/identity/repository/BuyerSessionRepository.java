package com.ticket.app.backend.identity.repository;

import java.time.Instant;
import java.util.Optional;
import com.ticket.app.backend.identity.model.BuyerSession;
import com.ticket.app.backend.identity.model.TokenHash;

/** Where signed-in user app devices are kept, by the hash of their access token. */
public interface BuyerSessionRepository {

    void add(BuyerSession session);

    Optional<BuyerSession> find(TokenHash tokenHash);

    void remove(TokenHash tokenHash);

    /** Deletes sessions that expired before {@code now}. @return how many */
    int removeExpired(Instant now);
}
