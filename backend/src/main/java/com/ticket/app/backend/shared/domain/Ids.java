package com.ticket.app.backend.shared.domain;

import java.security.SecureRandom;
import java.util.UUID;

/**
 * New identifiers, made by the domain before anything is saved.
 *
 * <p>UUID version 7: the first 48 bits are the time in milliseconds, so new rows
 * land at the end of database indexes instead of all over them.
 */
public final class Ids {

    private static final SecureRandom RANDOM = new SecureRandom();

    private Ids() {
    }

    public static UUID newId() {
        long millis = System.currentTimeMillis() & 0xFFFF_FFFF_FFFFL;
        long high = (millis << 16) | 0x7000L | (RANDOM.nextInt() & 0x0FFFL);
        long low = (RANDOM.nextLong() & 0x3FFF_FFFF_FFFF_FFFFL) | 0x8000_0000_0000_0000L;
        return new UUID(high, low);
    }
}
