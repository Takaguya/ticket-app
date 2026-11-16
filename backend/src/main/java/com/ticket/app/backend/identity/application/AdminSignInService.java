package com.ticket.app.backend.identity.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.admin.application.AdminDirectory;
import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.identity.domain.AdminPassword;
import com.ticket.app.backend.identity.domain.AdminPasswordRepository;
import com.ticket.app.backend.identity.domain.PasswordHasher;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.DomainException;
import com.ticket.app.backend.shared.domain.EmailAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Signing in to the admin panel with an email address and a password. The refusal is
 * the same, and takes as long, whether the address is nobody's or the password is
 * wrong, so it does not tell who is an admin.
 */
@Service
public class AdminSignInService {

    private static final Logger log = LoggerFactory.getLogger(AdminSignInService.class);

    private static final String WRONG_EMAIL_OR_PASSWORD = "The email or password is wrong.";

    private final AdminDirectory admins;
    private final AdminPasswordRepository passwords;
    private final PasswordHasher hasher;
    private final AdminSessionService sessions;
    private final Clock clock;
    private final PinProperties.AdminSignIn rules;

    /** Checked when the address has no password, so that takes as long as a wrong password. */
    private final String noAccountHash;

    public AdminSignInService(AdminDirectory admins, AdminPasswordRepository passwords, PasswordHasher hasher,
                              AdminSessionService sessions, Clock clock, PinProperties properties) {
        this.admins = admins;
        this.passwords = passwords;
        this.hasher = hasher;
        this.sessions = sessions;
        this.clock = clock;
        this.rules = properties.adminSignIn();
        this.noAccountHash = hasher.hash("nobody signs in with this");
        if (rules.devPasswordReset()) {
            log.warn("Anyone can set an admin's password from the admin panel's \"forgot password\" page. "
                    + "Never run like this in production.");
        }
    }

    /** Whether "forgot password" sets a new password straight away: on development servers only. */
    public boolean canResetPasswordsWithoutProof() {
        return rules.devPasswordReset();
    }

    /**
     * Development only ({@code pin.admin-sign-in.dev-password-reset}): gives the admin a
     * new password with no proof the person is that admin, lifts a lock, and signs the
     * admin out of every browser. Refused everywhere else.
     */
    @Transactional
    public void resetPasswordWithoutProof(String email, String newPassword) {
        if (!rules.devPasswordReset()) {
            throw BusinessRuleException.conflict(
                    "Passwords can only be reset here on a development server. Ask Pin's tech team to set a new one.");
        }
        AdminPassword.requireAllowed(newPassword);
        Admin admin = admins.findByEmail(EmailAddress.of(email))
                .orElseThrow(() -> BusinessRuleException.invalid("No Pin admin has this email address."));
        passwords.save(AdminPassword.set(admin.id(), newPassword, hasher));
        sessions.endAllFor(admin.id());
    }

    /**
     * A signed-in admin changes their password. The current one must be right, and
     * wrong guesses count as at sign-in, so a browser left signed in cannot be used to
     * find it out. Every other browser signed in as the admin is signed out; the one
     * using {@code accessToken} stays. Refusals do not roll back, so guesses stay counted.
     */
    @Transactional(noRollbackFor = DomainException.class)
    public void changePassword(Admin admin, String accessToken, String currentPassword, String newPassword) {
        AdminPassword.requireAllowed(newPassword);
        if (newPassword.equals(currentPassword)) {
            throw BusinessRuleException.invalid("Choose a new password, not your current one.");
        }
        AdminPassword current = passwords.findAndLock(admin.id())
                .orElseThrow(() -> new IllegalStateException("Signed-in admin " + admin.id() + " has no password"));
        Instant now = clock.instant();
        AdminPassword.Check check = current.check(currentPassword, hasher, now, rules.maxWrongPasswords(),
                rules.lockFor());
        if (check == AdminPassword.Check.CORRECT) {
            passwords.save(AdminPassword.set(admin.id(), newPassword, hasher));
            sessions.endAllOthers(admin.id(), accessToken);
            return;
        }
        passwords.save(current);
        throw check == AdminPassword.Check.LOCKED
                ? locked(current, now)
                : BusinessRuleException.invalid("Your current password is wrong.");
    }

    /**
     * Signs the admin in, or refuses. Refusals do not roll back, so a wrong password
     * stays counted; too many in a row lock sign-in for a while.
     */
    @Transactional(noRollbackFor = DomainException.class)
    public AdminSignedIn signIn(String email, String password) {
        Optional<Admin> admin = admins.findByEmail(EmailAddress.of(email));
        Optional<AdminPassword> stored = admin.flatMap(found -> passwords.findAndLock(found.id()));
        if (stored.isEmpty()) {
            hasher.matches(password, noAccountHash);
            throw BusinessRuleException.invalid(WRONG_EMAIL_OR_PASSWORD);
        }

        Instant now = clock.instant();
        AdminPassword current = stored.get();
        AdminPassword.Check check = current.check(password, hasher, now, rules.maxWrongPasswords(), rules.lockFor());
        passwords.save(current);
        return switch (check) {
            case CORRECT -> sessions.start(admin.get(), current.mustChange());
            case WRONG -> throw BusinessRuleException.invalid(WRONG_EMAIL_OR_PASSWORD);
            case LOCKED -> throw locked(current, now);
        };
    }

    private static BusinessRuleException locked(AdminPassword password, Instant now) {
        Duration left = Duration.between(now, password.lockedUntil().orElse(now));
        long minutes = Math.max(1, (left.toSeconds() + 59) / 60);
        return BusinessRuleException.tooSoon("Too many wrong passwords. Please try again in " + minutes
                + (minutes == 1 ? " minute." : " minutes."));
    }
}
