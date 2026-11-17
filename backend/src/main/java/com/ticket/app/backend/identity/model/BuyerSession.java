package com.ticket.app.backend.identity.model;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.buyer.model.BuyerId;

/**
 * A device signed in to the user app. Kept apart from merchant and admin sessions, so
 * a buyer's token can never act as either. The app holds the access token; the server
 * keeps its hash.
 */
public record BuyerSession(TokenHash tokenHash, BuyerId buyerId, Instant expiresAt) {

    /** A new session: the access token for the app, and the record to store. */
    public record Started(SecretToken accessToken, BuyerSession session) {
    }

    public BuyerSession {
        Objects.requireNonNull(tokenHash, "tokenHash");
        Objects.requireNonNull(buyerId, "buyerId");
        Objects.requireNonNull(expiresAt, "expiresAt");
    }

    public static Started start(BuyerId buyerId, Instant now, Duration ttl) {
        SecretToken token = SecretToken.generate();
        return new Started(token, new BuyerSession(token.hash(), buyerId, now.plus(ttl)));
    }

    public boolean isActiveAt(Instant now) {
        return now.isBefore(expiresAt);
    }
}
