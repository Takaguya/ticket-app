package com.ticket.app.backend.identity.model;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.admin.model.AdminId;

/**
 * A browser signed in to the admin panel. Kept apart from merchant sessions, so a
 * merchant's token can never act as an admin. The browser holds the token; the
 * server keeps its hash.
 */
public record AdminSession(TokenHash tokenHash, AdminId adminId, Instant expiresAt) {

    /** A new session: the access token for the browser, and the record to store. */
    public record Started(SecretToken accessToken, AdminSession session) {
    }

    public AdminSession {
        Objects.requireNonNull(tokenHash, "tokenHash");
        Objects.requireNonNull(adminId, "adminId");
        Objects.requireNonNull(expiresAt, "expiresAt");
    }

    public static Started start(AdminId adminId, Instant now, Duration ttl) {
        SecretToken token = SecretToken.generate();
        return new Started(token, new AdminSession(token.hash(), adminId, now.plus(ttl)));
    }

    public boolean isActiveAt(Instant now) {
        return now.isBefore(expiresAt);
    }
}
