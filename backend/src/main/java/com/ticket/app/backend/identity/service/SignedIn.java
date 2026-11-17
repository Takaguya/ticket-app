package com.ticket.app.backend.identity.service;

import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.identity.model.SecretToken;

/** A started session: the access token for the app, and who it signs in. */
public record SignedIn(SecretToken accessToken, StaffMember member) implements VerifyResult {
}
