package com.ticket.app.backend.identity.application;

import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.identity.domain.SecretToken;

/** A started session: the access token for the app, and who it signs in. */
public record SignedIn(SecretToken accessToken, StaffMember member) implements VerifyResult {
}
