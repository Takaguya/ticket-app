package com.ticket.app.backend.identity.application;

import java.time.Clock;
import java.time.Instant;

import com.ticket.app.backend.identity.domain.AdminSessionRepository;
import com.ticket.app.backend.identity.domain.BuyerSessionRepository;
import com.ticket.app.backend.identity.domain.OtpChallengeRepository;
import com.ticket.app.backend.identity.domain.RegistrationTokenRepository;
import com.ticket.app.backend.identity.domain.SessionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Deletes sign-in records nobody can use any more: expired sessions and
 * registration tokens, and finished codes. Runs every night at 03:15 Pin time.
 */
@Component
public class SignInHousekeeping {

    private static final Logger log = LoggerFactory.getLogger(SignInHousekeeping.class);

    private final SessionRepository sessions;
    private final AdminSessionRepository adminSessions;
    private final BuyerSessionRepository buyerSessions;
    private final RegistrationTokenRepository registrations;
    private final OtpChallengeRepository challenges;
    private final Clock clock;

    public SignInHousekeeping(SessionRepository sessions, AdminSessionRepository adminSessions,
                              BuyerSessionRepository buyerSessions, RegistrationTokenRepository registrations,
                              OtpChallengeRepository challenges, Clock clock) {
        this.sessions = sessions;
        this.adminSessions = adminSessions;
        this.buyerSessions = buyerSessions;
        this.registrations = registrations;
        this.challenges = challenges;
        this.clock = clock;
    }

    @Scheduled(cron = "0 15 3 * * *", zone = "${pin.time-zone:Asia/Phnom_Penh}")
    @Transactional
    public void removeExpired() {
        Instant now = clock.instant();
        int removedSessions = sessions.removeExpired(now) + adminSessions.removeExpired(now)
                + buyerSessions.removeExpired(now);
        int removedTokens = registrations.removeExpired(now);
        int removedCodes = challenges.removeFinished(now);
        log.info("Removed {} expired sessions, {} registration tokens and {} sign-in codes",
                removedSessions, removedTokens, removedCodes);
    }
}
