package com.ticket.app.backend.identity.infrastructure;

import com.ticket.app.backend.identity.domain.PasswordHasher;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * BCrypt, from Spring Security. Each hash holds its own random salt and its cost, so
 * the cost can be raised later and older hashes still check.
 */
@Component
class BCryptPasswordHasher implements PasswordHasher {

    /** 2^12 rounds: a fraction of a second per check, slow enough to make guessing costly. */
    private static final int STRENGTH = 12;

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(STRENGTH);

    @Override
    public String hash(String password) {
        return encoder.encode(password);
    }

    @Override
    public boolean matches(String password, String hash) {
        return encoder.matches(password, hash);
    }
}
