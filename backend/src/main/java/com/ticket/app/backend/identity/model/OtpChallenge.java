package com.ticket.app.backend.identity.model;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.shared.model.PhoneNumber;
import com.ticket.app.backend.shared.model.Secrets;

/**
 * The latest sign-in code sent to a phone number. Only a hash of the code is kept.
 *
 * <p>A correct code works once; wrong guesses are counted, and after too many even
 * the correct code is refused. Codes sent within an hour are counted too, so the
 * guesses per hour stay few: without that, asking for a new code every 30 seconds
 * would allow hundreds of guesses an hour.
 */
public final class OtpChallenge {

    /** What checking a code found. */
    public enum Check {
        CORRECT,
        WRONG,
        /** Expired, or too many wrong guesses: a new code is needed. */
        UNUSABLE
    }

    /** Whether another code may be sent to the number now. */
    public enum Resend {
        ALLOWED,
        /** The last code went out moments ago. */
        TOO_SOON,
        /** Enough codes were sent this hour. */
        HOURLY_LIMIT
    }

    /** The period sends are counted over. */
    public static final Duration WINDOW = Duration.ofHours(1);

    private final PhoneNumber phone;
    private final byte[] codeHash;
    private final Instant sentAt;
    private final Instant expiresAt;
    private final int sendsInWindow;
    private final Instant windowStartedAt;
    private int wrongAttempts;

    private OtpChallenge(PhoneNumber phone, byte[] codeHash, Instant sentAt, Instant expiresAt, int wrongAttempts,
                         int sendsInWindow, Instant windowStartedAt) {
        this.phone = Objects.requireNonNull(phone, "phone");
        this.codeHash = codeHash.clone();
        this.sentAt = Objects.requireNonNull(sentAt, "sentAt");
        this.expiresAt = Objects.requireNonNull(expiresAt, "expiresAt");
        this.wrongAttempts = wrongAttempts;
        this.sendsInWindow = sendsInWindow;
        this.windowStartedAt = Objects.requireNonNull(windowStartedAt, "windowStartedAt");
    }

    /** The first code sent to a number (in a while). */
    public static OtpChallenge send(PhoneNumber phone, String code, Instant now, Duration ttl) {
        return new OtpChallenge(phone, hash(phone, code), now, now.plus(ttl), 0, 1, now);
    }

    /** A code read back from storage. */
    public static OtpChallenge restore(PhoneNumber phone, byte[] codeHash, Instant sentAt, Instant expiresAt,
                                       int wrongAttempts, int sendsInWindow, Instant windowStartedAt) {
        return new OtpChallenge(phone, codeHash, sentAt, expiresAt, wrongAttempts, sendsInWindow, windowStartedAt);
    }

    /** Whether a new code may replace this one now. */
    public Resend resendCheck(Instant now, Duration resendAfter, int maxSendsPerHour) {
        if (now.isBefore(sentAt.plus(resendAfter))) {
            return Resend.TOO_SOON;
        }
        if (isInWindow(now) && sendsInWindow >= maxSendsPerHour) {
            return Resend.HOURLY_LIMIT;
        }
        return Resend.ALLOWED;
    }

    /** A new code replacing this one. It counts towards this hour's sends. */
    public OtpChallenge resend(String code, Instant now, Duration ttl) {
        boolean sameWindow = isInWindow(now);
        return new OtpChallenge(phone, hash(phone, code), now, now.plus(ttl), 0,
                sameWindow ? sendsInWindow + 1 : 1, sameWindow ? windowStartedAt : now);
    }

    /** Checks a guess. A wrong guess is counted on this challenge, which must then be saved. */
    public Check check(String code, Instant now, int maxAttempts) {
        if (!now.isBefore(expiresAt) || wrongAttempts >= maxAttempts) {
            return Check.UNUSABLE;
        }
        if (Secrets.sameHash(codeHash, hash(phone, code))) {
            return Check.CORRECT;
        }
        wrongAttempts++;
        return Check.WRONG;
    }

    public PhoneNumber phone() {
        return phone;
    }

    public byte[] codeHash() {
        return codeHash.clone();
    }

    public Instant sentAt() {
        return sentAt;
    }

    public Instant expiresAt() {
        return expiresAt;
    }

    public int wrongAttempts() {
        return wrongAttempts;
    }

    public int sendsInWindow() {
        return sendsInWindow;
    }

    public Instant windowStartedAt() {
        return windowStartedAt;
    }

    private boolean isInWindow(Instant now) {
        return now.isBefore(windowStartedAt.plus(WINDOW));
    }

    private static byte[] hash(PhoneNumber phone, String code) {
        return Secrets.sha256(phone.value() + ':' + code);
    }
}
