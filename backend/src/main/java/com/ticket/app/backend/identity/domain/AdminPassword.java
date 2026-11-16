package com.ticket.app.backend.identity.domain;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.Secrets;

/**
 * An admin's password for the admin panel. Only a hash of it is kept.
 *
 * <p>Wrong passwords are counted. Too many in a row lock sign-in for a while, even
 * with the right password, so a password cannot be found by trying many. The right
 * password starts the count again.
 */
public final class AdminPassword {

    /** What checking a password found. */
    public enum Check {
        CORRECT,
        WRONG,
        /** Too many wrong passwords in a row: refused until {@link #lockedUntil()}. */
        LOCKED
    }

    public static final int MIN_LENGTH = 12;

    /** BCrypt reads only the first 72 bytes of a password and would ignore the rest. */
    public static final int MAX_BYTES = 72;

    /** Letters and digits that cannot be mistaken for each other: no i, l, o, 0 or 1. */
    private static final String TEMPORARY_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";

    private final AdminId adminId;
    private final String hash;
    private final boolean mustChange;
    private int wrongAttempts;
    private Instant lockedUntil;

    private AdminPassword(AdminId adminId, String hash, boolean mustChange, int wrongAttempts, Instant lockedUntil) {
        this.adminId = Objects.requireNonNull(adminId, "adminId");
        this.hash = Objects.requireNonNull(hash, "hash");
        this.mustChange = mustChange;
        this.wrongAttempts = wrongAttempts;
        this.lockedUntil = lockedUntil;
    }

    /** The admin's own new password. It replaces any earlier one and lifts a lock. */
    public static AdminPassword set(AdminId adminId, String password, PasswordHasher hasher) {
        requireAllowed(password);
        return new AdminPassword(adminId, hasher.hash(password), false, 0, null);
    }

    /**
     * A password someone else passes on to the admin, e.g. when adding them. It signs
     * in, but the admin must choose their own before doing anything else.
     */
    public static AdminPassword temporary(AdminId adminId, String password, PasswordHasher hasher) {
        requireAllowed(password);
        return new AdminPassword(adminId, hasher.hash(password), true, 0, null);
    }

    /** A password read back from storage. {@code lockedUntil} is null when it was never locked. */
    public static AdminPassword restore(AdminId adminId, String hash, boolean mustChange, int wrongAttempts,
                                        Instant lockedUntil) {
        return new AdminPassword(adminId, hash, mustChange, wrongAttempts, lockedUntil);
    }

    /**
     * A new random temporary password, easy to read out or type: 16 letters and digits
     * in groups of 4, e.g. {@code k7mp-x3qa-9fzt-h2wd} (about 79 bits).
     */
    public static String newTemporaryPassword() {
        StringBuilder password = new StringBuilder(19);
        for (int i = 0; i < 16; i++) {
            if (i > 0 && i % 4 == 0) {
                password.append('-');
            }
            password.append(TEMPORARY_ALPHABET.charAt(Secrets.below(TEMPORARY_ALPHABET.length())));
        }
        return password.toString();
    }

    /** Refuses passwords too short to be safe, or too long for the hash. */
    public static void requireAllowed(String password) {
        if (password == null || password.codePointCount(0, password.length()) < MIN_LENGTH) {
            throw BusinessRuleException.invalid("A password needs at least " + MIN_LENGTH + " characters.");
        }
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            throw BusinessRuleException.invalid("A password can have at most " + MAX_BYTES
                    + " characters, fewer with accents or non-Latin letters.");
        }
    }

    /**
     * Checks a password typed at sign-in. A wrong one is counted, and the one that
     * reaches {@code maxWrong} in a row locks sign-in for {@code lockFor}. The password
     * must then be saved.
     */
    public Check check(String password, PasswordHasher hasher, Instant now, int maxWrong, Duration lockFor) {
        if (isLockedAt(now)) {
            return Check.LOCKED;
        }
        if (hasher.matches(password, hash)) {
            wrongAttempts = 0;
            lockedUntil = null;
            return Check.CORRECT;
        }
        wrongAttempts++;
        if (wrongAttempts >= maxWrong) {
            // After the lock, another maxWrong tries.
            wrongAttempts = 0;
            lockedUntil = now.plus(lockFor);
            return Check.LOCKED;
        }
        return Check.WRONG;
    }

    /** Whether this is the password, without counting anything. */
    public boolean matches(String password, PasswordHasher hasher) {
        return hasher.matches(password, hash);
    }

    public boolean isLockedAt(Instant now) {
        return lockedUntil != null && now.isBefore(lockedUntil);
    }

    public AdminId adminId() {
        return adminId;
    }

    public String hash() {
        return hash;
    }

    /** Whether this is a temporary password the admin must replace with their own. */
    public boolean mustChange() {
        return mustChange;
    }

    public int wrongAttempts() {
        return wrongAttempts;
    }

    public Optional<Instant> lockedUntil() {
        return Optional.ofNullable(lockedUntil);
    }
}
