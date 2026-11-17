package com.ticket.app.backend.identity.dto;

import com.ticket.app.backend.identity.service.SignedIn;

/** A merchant app session: the access token and who it is for. */
public record SessionResponse(String accessToken, UserResponse user) {

    public static SessionResponse of(SignedIn signedIn) {
        return new SessionResponse(signedIn.accessToken().value(), UserResponse.of(signedIn.member()));
    }
}
