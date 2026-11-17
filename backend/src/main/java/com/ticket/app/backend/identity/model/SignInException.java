package com.ticket.app.backend.identity.model;

import com.ticket.app.backend.shared.model.DomainException;

/** Sign-in refusals with their own error codes, which the apps handle specially. */
public final class SignInException extends DomainException {

    private SignInException(String code, String message) {
        super(Kind.INVALID, code, message);
    }

    /** {@code invalid_code}: the app asks for the code again. */
    public static SignInException invalidCode() {
        return new SignInException("invalid_code", "The code is wrong or has expired.");
    }

    /** {@code invalid_registration}: the app sends the person back to confirm their number. */
    public static SignInException registrationExpired(String message) {
        return new SignInException("invalid_registration", message);
    }
}
