package com.ticket.app.backend.identity.model;

import java.util.Arrays;

import com.ticket.app.backend.shared.model.Secrets;

/** The SHA-256 of a {@link SecretToken}: what is stored and looked up. */
public final class TokenHash {

    private final byte[] bytes;

    private TokenHash(byte[] bytes) {
        this.bytes = bytes.clone();
    }

    public static TokenHash of(String token) {
        return new TokenHash(Secrets.sha256(token));
    }

    /** A hash read back from storage. */
    public static TokenHash fromBytes(byte[] bytes) {
        return new TokenHash(bytes);
    }

    public byte[] bytes() {
        return bytes.clone();
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof TokenHash that && Secrets.sameHash(bytes, that.bytes);
    }

    @Override
    public int hashCode() {
        return Arrays.hashCode(bytes);
    }

    @Override
    public String toString() {
        return "TokenHash[hidden]";
    }
}
