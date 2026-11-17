package com.ticket.app.backend.identity.model;

import java.util.Objects;

import com.ticket.app.backend.shared.model.Secrets;

/**
 * A secret handed to the app once (an access or registration token). The server
 * keeps only its {@link #hash()}.
 */
public record SecretToken(String value) {

    public SecretToken {
        Objects.requireNonNull(value, "value");
    }

    public static SecretToken generate() {
        return new SecretToken(Secrets.newToken());
    }

    public TokenHash hash() {
        return TokenHash.of(value);
    }

    /** Never print the secret, e.g. in logs. */
    @Override
    public String toString() {
        return "SecretToken[hidden]";
    }
}
