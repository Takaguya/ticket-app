package com.ticket.app.backend.identity.service;

import com.ticket.app.backend.identity.model.SecretToken;

/** What a correct sign-in code leads to. */
public sealed interface VerifyResult permits SignedIn, BuyerSignedIn, VerifyResult.NewNumber {

    /**
     * The number has no account yet. The token lets it register a business or join one,
     * or, in the user app, register as a buyer.
     */
    record NewNumber(SecretToken registrationToken) implements VerifyResult {
    }
}
