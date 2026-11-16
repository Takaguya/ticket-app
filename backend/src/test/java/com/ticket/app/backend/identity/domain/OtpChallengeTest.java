package com.ticket.app.backend.identity.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;

import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.junit.jupiter.api.Test;

class OtpChallengeTest {

    private static final PhoneNumber PHONE = new PhoneNumber("+85512345678");
    private static final Instant SENT = Instant.parse("2026-11-12T02:00:00Z");
    private static final Duration TTL = Duration.ofMinutes(5);

    private final OtpChallenge challenge = OtpChallenge.send(PHONE, "123456", SENT, TTL);

    @Test
    void theRightCodeWithinFiveMinutesIsCorrect() {
        assertThat(challenge.check("123456", SENT.plusSeconds(299), 5)).isEqualTo(OtpChallenge.Check.CORRECT);
    }

    @Test
    void wrongGuessesAreCountedAndTooManyMakeTheCodeUnusable() {
        for (int i = 1; i <= 5; i++) {
            assertThat(challenge.check("000000", SENT, 5)).isEqualTo(OtpChallenge.Check.WRONG);
            assertThat(challenge.wrongAttempts()).isEqualTo(i);
        }

        assertThat(challenge.check("123456", SENT, 5)).isEqualTo(OtpChallenge.Check.UNUSABLE);
    }

    @Test
    void anExpiredCodeIsUnusable() {
        assertThat(challenge.check("123456", SENT.plus(TTL), 5)).isEqualTo(OtpChallenge.Check.UNUSABLE);
    }

    @Test
    void aNewCodeCanBeSentAfter30Seconds() {
        Duration resendAfter = Duration.ofSeconds(30);

        assertThat(challenge.resendCheck(SENT.plusSeconds(29), resendAfter, 5)).isEqualTo(OtpChallenge.Resend.TOO_SOON);
        assertThat(challenge.resendCheck(SENT.plusSeconds(30), resendAfter, 5)).isEqualTo(OtpChallenge.Resend.ALLOWED);
    }

    @Test
    void onlyFiveCodesAnHourCanBeSentToANumber() {
        Duration resendAfter = Duration.ofSeconds(30);
        OtpChallenge latest = challenge;
        Instant now = SENT;
        for (int sent = 1; sent < 5; sent++) {
            now = now.plusSeconds(60);
            assertThat(latest.resendCheck(now, resendAfter, 5)).isEqualTo(OtpChallenge.Resend.ALLOWED);
            latest = latest.resend("12345" + sent, now, TTL);
        }
        assertThat(latest.sendsInWindow()).isEqualTo(5);

        assertThat(latest.resendCheck(now.plusSeconds(60), resendAfter, 5))
                .isEqualTo(OtpChallenge.Resend.HOURLY_LIMIT);
        // An hour after the first code the count starts again.
        Instant nextHour = SENT.plus(OtpChallenge.WINDOW);
        assertThat(latest.resendCheck(nextHour, resendAfter, 5)).isEqualTo(OtpChallenge.Resend.ALLOWED);
        assertThat(latest.resend("654321", nextHour, TTL).sendsInWindow()).isEqualTo(1);
    }

    @Test
    void aResentCodeReplacesTheOldOneAndStartsWithNoWrongGuesses() {
        challenge.check("000000", SENT, 5);
        OtpChallenge resent = challenge.resend("654321", SENT.plusSeconds(30), TTL);

        assertThat(resent.wrongAttempts()).isZero();
        assertThat(resent.check("123456", SENT.plusSeconds(31), 5)).isEqualTo(OtpChallenge.Check.WRONG);
        assertThat(resent.check("654321", SENT.plusSeconds(32), 5)).isEqualTo(OtpChallenge.Check.CORRECT);
    }

    @Test
    void onlyAHashOfTheCodeIsKept() {
        assertThat(new String(challenge.codeHash())).doesNotContain("123456");
        assertThat(challenge.codeHash()).hasSize(32);
    }
}
