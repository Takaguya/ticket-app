package com.ticket.app.backend.shared.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

/** Unguessable random values, and the hashes stored in their place. */
public final class Secrets {

    private static final SecureRandom RANDOM = new SecureRandom();

    private Secrets() {
    }

    /** 256 random bits as 43 URL-safe characters. */
    public static String newToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** {@code count} random decimal digits. */
    public static String digits(int count) {
        StringBuilder digits = new StringBuilder(count);
        for (int i = 0; i < count; i++) {
            digits.append(RANDOM.nextInt(10));
        }
        return digits.toString();
    }

    /** A random number from 0 (inclusive) to {@code bound} (exclusive). */
    public static int below(int bound) {
        return RANDOM.nextInt(bound);
    }

    /** SHA-256 of the UTF-8 bytes of {@code value}. */
    public static byte[] sha256(String value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("Every Java runtime has SHA-256", e);
        }
    }

    /** Compares two hashes in constant time, so timing reveals nothing. */
    public static boolean sameHash(byte[] a, byte[] b) {
        return MessageDigest.isEqual(a, b);
    }
}
