package com.ticket.app.backend.identity.application;

import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.identity.domain.SecretToken;

/**
 * A started admin session: the access token for the browser, who it signs in, and
 * whether they signed in with a temporary password, so must choose their own first.
 */
public record AdminSignedIn(SecretToken accessToken, Admin admin, boolean mustChangePassword) {
}
