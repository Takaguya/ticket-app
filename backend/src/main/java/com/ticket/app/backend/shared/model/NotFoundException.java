package com.ticket.app.backend.shared.model;

/** The thing asked for does not exist, or belongs to another business. */
public final class NotFoundException extends DomainException {

    public NotFoundException(String message) {
        super(Kind.NOT_FOUND, "not_found", message);
    }
}
