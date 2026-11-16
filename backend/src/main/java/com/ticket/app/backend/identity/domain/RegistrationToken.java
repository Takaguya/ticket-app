package com.ticket.app.backend.identity.domain;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.shared.domain.PhoneNumber;

/**
 * Proof that a phone number with no account was confirmed by code. The app sends
 * the token back with the register or join form. Wrong join codes are counted so
 * that codes cannot be guessed one by one.
 */
public final class RegistrationToken {

    public static final int MAX_WRONG_JOIN_CODES = 5;

    /** A new token: the secret for the app, and the record to store. */
    public record Issued(SecretToken token, RegistrationToken registration) {
    }

    private final TokenHash tokenHash;
    private final PhoneNumber phone;
    private final Instant expiresAt;
    private int wrongJoinCodes;

    private RegistrationToken(TokenHash tokenHash, PhoneNumber phone, Instant expiresAt, int wrongJoinCodes) {
        this.tokenHash = Objects.requireNonNull(tokenHash, "tokenHash");
        this.phone = Objects.requireNonNull(phone, "phone");
        this.expiresAt = Objects.requireNonNull(expiresAt, "expiresAt");
        this.wrongJoinCodes = wrongJoinCodes;
    }

    public static Issued issue(PhoneNumber phone, Instant now, Duration ttl) {
        SecretToken token = SecretToken.generate();
        return new Issued(token, new RegistrationToken(token.hash(), phone, now.plus(ttl), 0));
    }

    public static RegistrationToken restore(TokenHash tokenHash, PhoneNumber phone, Instant expiresAt,
                                            int wrongJoinCodes) {
        return new RegistrationToken(tokenHash, phone, expiresAt, wrongJoinCodes);
    }

    public boolean isUsableAt(Instant now) {
        return now.isBefore(expiresAt) && wrongJoinCodes < MAX_WRONG_JOIN_CODES;
    }

    /**
     * Counts a wrong join code.
     *
     * @return whether the person may try another code with this token
     */
    public boolean recordWrongJoinCode() {
        wrongJoinCodes++;
        return wrongJoinCodes < MAX_WRONG_JOIN_CODES;
    }

    public TokenHash tokenHash() {
        return tokenHash;
    }

    public PhoneNumber phone() {
        return phone;
    }

    public Instant expiresAt() {
        return expiresAt;
    }

    public int wrongJoinCodes() {
        return wrongJoinCodes;
    }
}
