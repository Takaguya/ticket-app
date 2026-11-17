package com.ticket.app.backend.identity.service;

import com.ticket.app.backend.shared.model.PhoneNumber;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Stand-in until an SMS provider is chosen: notes that a message would be sent,
 * without its text, because the text holds a sign-in code and logs must never.
 * Until a real provider replaces it, codes reach nobody, so only the development
 * code ({@code pin.otp.dev-code}) can sign in.
 */
@Component
class LoggingSmsSender implements SmsSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    LoggingSmsSender() {
        log.warn("No SMS provider is set up: sign-in codes are not delivered.");
    }

    @Override
    public void send(PhoneNumber phone, String message) {
        log.info("SMS not sent (no provider) to {}", masked(phone));
    }

    /** {@code +855 ***** 678}: enough to tell numbers apart in a log. */
    private static String masked(PhoneNumber phone) {
        String digits = phone.value();
        return "+855 ***** " + digits.substring(digits.length() - 3);
    }
}
