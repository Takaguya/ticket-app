package com.ticket.app.backend.identity.service;

import java.util.Arrays;

/** Which Pin app is signing in: the merchant app's staff, or the user app's buyers. */
public enum SignInApp {
    MERCHANT("merchant"),
    USER("user");

    private final String code;

    SignInApp(String code) {
        this.code = code;
    }

    /** The stable name used in the API. */
    public String code() {
        return code;
    }

    /** The app named in a request. Requests that name none are the merchant app's, as before buyers existed. */
    public static SignInApp fromCode(String code) {
        return Arrays.stream(values())
                .filter(app -> app.code.equals(code))
                .findFirst()
                .orElse(MERCHANT);
    }
}
