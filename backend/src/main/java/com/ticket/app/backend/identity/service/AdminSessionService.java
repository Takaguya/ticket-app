package com.ticket.app.backend.identity.service;

import java.time.Clock;
import java.util.Optional;

import com.ticket.app.backend.admin.service.AdminDirectory;
import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.admin.model.AdminId;
import com.ticket.app.backend.identity.repository.AdminPasswordRepository;
import com.ticket.app.backend.identity.model.AdminSession;
import com.ticket.app.backend.identity.repository.AdminSessionRepository;
import com.ticket.app.backend.identity.model.TokenHash;
import com.ticket.app.backend.shared.config.PinProperties;
import org.springframework.stereotype.Service;

/**
 * Signed-in admin browsers. The admin panel sends its access token as
 * {@code Authorization: Bearer <token>} on every request. Admin sessions are shorter
 * than the apps' ({@code pin.admin-session-ttl}).
 */
@Service
public class AdminSessionService {

    /**
     * Who a session signs in, and whether they still have a temporary password: then
     * they may only choose their own password or sign out.
     */
    public record SignedInAdmin(Admin admin, boolean mustChangePassword) {
    }

    private final AdminSessionRepository sessions;
    private final AdminDirectory admins;
    private final AdminPasswordRepository passwords;
    private final Clock clock;
    private final PinProperties properties;

    public AdminSessionService(AdminSessionRepository sessions, AdminDirectory admins,
                               AdminPasswordRepository passwords, Clock clock, PinProperties properties) {
        this.sessions = sessions;
        this.admins = admins;
        this.passwords = passwords;
        this.clock = clock;
        this.properties = properties;
    }

    /** @param mustChangePassword the admin signed in with a temporary password */
    public AdminSignedIn start(Admin admin, boolean mustChangePassword) {
        AdminSession.Started started = AdminSession.start(admin.id(), clock.instant(), properties.adminSessionTtl());
        sessions.add(started.session());
        return new AdminSignedIn(started.accessToken(), admin, mustChangePassword);
    }

    /** Who an access token signs in. Empty when it is unknown or expired. */
    public Optional<SignedInAdmin> resolve(String accessToken) {
        return sessions.find(TokenHash.of(accessToken))
                .filter(session -> session.isActiveAt(clock.instant()))
                .flatMap(session -> admins.find(session.adminId()))
                .map(admin -> new SignedInAdmin(admin, passwords.mustChange(admin.id())));
    }

    /** Signs the browser out: its token stops working. */
    public void end(String accessToken) {
        sessions.remove(TokenHash.of(accessToken));
    }

    /** Signs the admin out of every browser, e.g. after their password changed. */
    public void endAllFor(AdminId adminId) {
        sessions.removeAllFor(adminId);
    }

    /** Signs the admin out of every browser but the one using this access token. */
    public void endAllOthers(AdminId adminId, String accessToken) {
        sessions.removeAllForExcept(adminId, TokenHash.of(accessToken));
    }
}
