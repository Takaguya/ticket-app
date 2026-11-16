package com.ticket.app.backend.identity.domain;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.shared.domain.PhoneNumber;

/** Where the latest sign-in code per phone number is kept. */
public interface OtpChallengeRepository {

    /**
     * The number's code, held until the transaction ends so that two requests for the
     * same number are handled one after the other.
     */
    Optional<OtpChallenge> findAndLock(PhoneNumber phone);

    /**
     * Saves a code for a number that had none.
     *
     * @return false when another request saved one for the number at the same moment
     */
    boolean tryAdd(OtpChallenge challenge);

    /** Replaces the number's code, or saves its new wrong-attempt count. */
    void update(OtpChallenge challenge);

    void remove(PhoneNumber phone);

    /**
     * Deletes codes that have expired and whose hour of counted sends is over, so
     * forgetting them does not reset a number's hourly limit.
     *
     * @return how many were deleted
     */
    int removeFinished(Instant now);
}
