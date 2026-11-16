package com.ticket.app.backend.identity;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.UUID;

import com.ticket.app.backend.ApiTest;
import com.ticket.app.backend.identity.application.SignInHousekeeping;
import com.ticket.app.backend.shared.domain.Secrets;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;

/** The nightly clean-up deletes what nobody can use any more, and nothing else. */
class SignInHousekeepingTest extends ApiTest {

    private static final UUID DEMO_OWNER = UUID.fromString("20000000-0000-7000-8000-000000000001");

    @Autowired
    SignInHousekeeping housekeeping;

    @Autowired
    JdbcClient jdbc;

    @Test
    void expiredSessionsAndTokensAreDeletedAndLiveOnesKept() {
        byte[] expiredSession = Secrets.sha256("expired-session");
        byte[] liveSession = Secrets.sha256("live-session");
        byte[] expiredToken = Secrets.sha256("expired-registration");
        OffsetDateTime now = OffsetDateTime.now();
        insertSession(expiredSession, now.minusDays(1));
        insertSession(liveSession, now.plusDays(1));
        jdbc.sql("insert into registration_tokens (token_hash, phone, expires_at) values (:hash, '+85570000300', :at)")
                .param("hash", expiredToken)
                .param("at", now.minusMinutes(1))
                .update();

        housekeeping.removeExpired();

        assertThat(sessionExists(expiredSession)).isFalse();
        assertThat(sessionExists(liveSession)).isTrue();
        assertThat(jdbc.sql("select count(*) from registration_tokens where token_hash = :hash")
                .param("hash", expiredToken).query(Long.class).single()).isZero();

        jdbc.sql("delete from sessions where token_hash = :hash").param("hash", liveSession).update();
    }

    private void insertSession(byte[] tokenHash, OffsetDateTime expiresAt) {
        jdbc.sql("insert into sessions (token_hash, member_id, expires_at) values (:hash, :member, :at)")
                .param("hash", tokenHash)
                .param("member", DEMO_OWNER)
                .param("at", expiresAt)
                .update();
    }

    private boolean sessionExists(byte[] tokenHash) {
        return jdbc.sql("select count(*) from sessions where token_hash = :hash")
                .param("hash", tokenHash).query(Long.class).single() == 1;
    }
}
