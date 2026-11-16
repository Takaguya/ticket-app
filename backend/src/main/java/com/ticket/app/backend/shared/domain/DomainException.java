package com.ticket.app.backend.shared.domain;

/**
 * A rule of the business said no. The domain knows nothing about HTTP: it says
 * what kind of problem this is, and the web layer turns that into a status.
 *
 * <p>{@link #code()} is the error code the apps act on; for {@code rejected} they
 * show {@link #getMessage()} to the person as written.
 */
public abstract class DomainException extends RuntimeException {

    public enum Kind {
        /** The input cannot be accepted. */
        INVALID,
        /** The request clashes with the current state, e.g. sold out. */
        CONFLICT,
        NOT_FOUND,
        /** Asked again too soon. */
        TOO_SOON
    }

    public static final String REJECTED = "rejected";

    private final Kind kind;
    private final String code;

    protected DomainException(Kind kind, String code, String message) {
        super(message);
        this.kind = kind;
        this.code = code;
    }

    public Kind kind() {
        return kind;
    }

    public String code() {
        return code;
    }
}
