package com.ticket.app.backend.identity.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.ticket.app.backend.identity.service.BuyerSignedIn;
import com.ticket.app.backend.identity.service.SignedIn;
import com.ticket.app.backend.identity.service.VerifyResult;

/**
 * Exactly one field is present. {@code session} is a {@link SessionResponse} for the
 * merchant app and a {@link BuyerSessionResponse} for the user app: the same JSON
 * shape, {@code {accessToken, user}}, with the user of that app.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record VerifyResponse(Object session, String registrationToken) {

    public static VerifyResponse of(VerifyResult result) {
        return switch (result) {
            case SignedIn signedIn -> new VerifyResponse(SessionResponse.of(signedIn), null);
            case BuyerSignedIn signedIn -> new VerifyResponse(BuyerSessionResponse.of(signedIn), null);
            case VerifyResult.NewNumber newNumber ->
                    new VerifyResponse(null, newNumber.registrationToken().value());
        };
    }
}
