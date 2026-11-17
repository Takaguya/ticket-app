package com.ticket.app.backend.identity.service;

import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.identity.model.SecretToken;

/**
 * A started admin session: the access token for the browser, who it signs in, and
 * whether they signed in with a temporary password, so must choose their own first.
 */
public record AdminSignedIn(SecretToken accessToken, Admin admin, boolean mustChangePassword) {
}
