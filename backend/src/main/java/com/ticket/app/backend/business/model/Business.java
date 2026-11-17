package com.ticket.app.backend.business.model;

import java.util.Objects;

import com.ticket.app.backend.shared.model.BusinessRuleException;

/**
 * A merchant on Pin: a running club, a bus company, a cinema... It sells only once an
 * admin has approved it ({@link BusinessStatus}).
 */
public record Business(BusinessId id, String name, BusinessType type, JoinCode joinCode, BusinessStatus status) {

    static final int MAX_NAME_LENGTH = 80;

    public Business {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(type, "type");
        Objects.requireNonNull(joinCode, "joinCode");
        Objects.requireNonNull(status, "status");
    }

    /** A newly registered business with a random join code, waiting for approval. */
    public static Business register(String name, BusinessType type) {
        String cleanName = name == null ? "" : name.strip();
        if (cleanName.isEmpty()) {
            throw BusinessRuleException.invalid("Enter the business name.");
        }
        if (cleanName.length() > MAX_NAME_LENGTH) {
            throw BusinessRuleException.invalid("Keep the business name under 80 characters.");
        }
        return new Business(BusinessId.newId(), cleanName, type, JoinCode.random(), BusinessStatus.PENDING);
    }

    /** The same business with another join code, e.g. because the drawn one is taken. */
    public Business withJoinCode(JoinCode newCode) {
        return new Business(id, name, type, newCode, status);
    }

    /** An admin lets a new business sell. */
    public Business approve() {
        if (status != BusinessStatus.PENDING) {
            throw BusinessRuleException.conflict(name + " is already " + describe(status) + ".");
        }
        return withStatus(BusinessStatus.ACTIVE);
    }

    /** An admin stops an active business from selling. */
    public Business suspend() {
        if (status != BusinessStatus.ACTIVE) {
            throw BusinessRuleException.conflict(status == BusinessStatus.PENDING
                    ? name + " is not approved yet."
                    : name + " is already suspended.");
        }
        return withStatus(BusinessStatus.SUSPENDED);
    }

    /** An admin lets a suspended business sell again. */
    public Business reinstate() {
        if (status != BusinessStatus.SUSPENDED) {
            throw BusinessRuleException.conflict(name + " is not suspended.");
        }
        return withStatus(BusinessStatus.ACTIVE);
    }

    public boolean isActive() {
        return status == BusinessStatus.ACTIVE;
    }

    /** Selling tickets, at the door or online, needs an approved business that is not suspended. */
    public void ensureCanSell() {
        switch (status) {
            case PENDING -> throw BusinessRuleException.conflict(
                    "Pin is still reviewing your business. You can sell tickets once it is approved.");
            case SUSPENDED -> throw BusinessRuleException.conflict(
                    "Pin has suspended your business. Contact Pin to sell tickets again.");
            case ACTIVE -> {
            }
        }
    }

    /** A business waiting for approval may set up events; a suspended one may not. */
    public void ensureCanPublish() {
        if (status == BusinessStatus.SUSPENDED) {
            throw BusinessRuleException.conflict(
                    "Pin has suspended your business. Contact Pin to publish events again.");
        }
    }

    private Business withStatus(BusinessStatus newStatus) {
        return new Business(id, name, type, joinCode, newStatus);
    }

    private static String describe(BusinessStatus status) {
        return status == BusinessStatus.ACTIVE ? "approved" : "suspended";
    }
}
