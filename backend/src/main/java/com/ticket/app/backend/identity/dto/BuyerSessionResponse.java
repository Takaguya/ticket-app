package com.ticket.app.backend.identity.dto;

import com.ticket.app.backend.identity.service.BuyerSignedIn;

/** A buyer's session in the user app: the access token and who it is for. */
public record BuyerSessionResponse(String accessToken, BuyerResponse user) {

    public static BuyerSessionResponse of(BuyerSignedIn signedIn) {
        return new BuyerSessionResponse(signedIn.accessToken().value(), BuyerResponse.of(signedIn.buyer()));
    }
}
