package com.ticket.app.backend.identity.model;

/**
 * Turns a password into a hash that can be stored, and checks a password against it.
 * Deliberately slow, with a random salt in each hash. Implemented in infrastructure.
 */
public interface PasswordHasher {

    String hash(String password);

    boolean matches(String password, String hash);
}
