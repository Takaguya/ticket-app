package com.ticket.app.backend.identity.application;

import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.identity.domain.SecretToken;

/** A started user app session: the access token for the app, and who it signs in. */
public record BuyerSignedIn(SecretToken accessToken, Buyer buyer) implements VerifyResult {
}
