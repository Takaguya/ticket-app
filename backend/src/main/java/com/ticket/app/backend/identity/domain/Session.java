package com.ticket.app.backend.identity.domain;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.business.domain.StaffId;

/**
 * A signed-in device. The app holds the access token; the server keeps its hash.
 */
public record Session(TokenHash tokenHash, StaffId staffId, Instant expiresAt) {

    /** A new session: the access token for the app, and the record to store. */
    public record Started(SecretToken accessToken, Session session) {
    }

    public Session {
        Objects.requireNonNull(tokenHash, "tokenHash");
        Objects.requireNonNull(staffId, "staffId");
        Objects.requireNonNull(expiresAt, "expiresAt");
    }

    public static Started start(StaffId staffId, Instant now, Duration ttl) {
        SecretToken token = SecretToken.generate();
        return new Started(token, new Session(token.hash(), staffId, now.plus(ttl)));
    }

    public boolean isActiveAt(Instant now) {
        return now.isBefore(expiresAt);
    }
}
