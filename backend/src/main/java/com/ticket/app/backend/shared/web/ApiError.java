package com.ticket.app.backend.shared.web;

/**
 * The body of every error answer: {@code {"code": "...", "message": "..."}}.
 * Codes from the domain ({@code rejected}, {@code invalid_code}, ...) come with the
 * exception; these are the ones the web layer adds itself.
 */
public record ApiError(String code, String message) {

    /** No valid session: sign in again. */
    public static final String UNAUTHORIZED = "unauthorized";

    /** Signed in, but this role may not do that. */
    public static final String FORBIDDEN = "forbidden";

    public static final String REJECTED = "rejected";
    public static final String NOT_FOUND = "not_found";
    public static final String BAD_REQUEST = "bad_request";
    public static final String SERVER_ERROR = "server_error";

    /**
     * The database cannot be reached (503). Whether the request was saved is unknown,
     * so the app retries it with the same attempt ID.
     */
    public static final String UNAVAILABLE = "unavailable";

    /** Shown to the person while the database is down. */
    public static final String UNAVAILABLE_MESSAGE = "Pin can't save right now. Please try again in a moment.";
}
