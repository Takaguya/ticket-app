package com.ticket.app.backend.shared.domain;

/** A business rule refused the request. The message is written for the person. */
public final class BusinessRuleException extends DomainException {

    private BusinessRuleException(Kind kind, String message) {
        super(kind, REJECTED, message);
    }

    /** The input breaks a rule, e.g. an event date in the past. */
    public static BusinessRuleException invalid(String message) {
        return new BusinessRuleException(Kind.INVALID, message);
    }

    /** The current state does not allow it, e.g. no tickets left. */
    public static BusinessRuleException conflict(String message) {
        return new BusinessRuleException(Kind.CONFLICT, message);
    }

    /** The same thing was asked for too recently. */
    public static BusinessRuleException tooSoon(String message) {
        return new BusinessRuleException(Kind.TOO_SOON, message);
    }
}
