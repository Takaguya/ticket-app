package com.ticket.app.backend.identity.repository;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.shared.model.PhoneNumber;
import com.ticket.app.backend.identity.model.RegistrationToken;
import com.ticket.app.backend.identity.model.TokenHash;

/** Where registration tokens are kept, by the hash of the token. */
public interface RegistrationTokenRepository {

    void add(RegistrationToken registration);

    /** The token, held until the transaction ends so it cannot be used twice at once. */
    Optional<RegistrationToken> findAndLock(TokenHash tokenHash);

    /** Saves the new wrong-join-code count. */
    void update(RegistrationToken registration);

    void remove(TokenHash tokenHash);

    /** Earlier tokens for a number stop working when a new one is issued. */
    void removeAllFor(PhoneNumber phone);

    /** Deletes tokens that expired before {@code now}. @return how many */
    int removeExpired(Instant now);
}
