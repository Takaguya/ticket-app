package com.ticket.app.backend.identity.repository;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

import com.ticket.app.backend.identity.model.OtpChallenge;
import com.ticket.app.backend.shared.model.PhoneNumber;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcOtpChallengeRepository implements OtpChallengeRepository {

    private final JdbcClient jdbc;

    JdbcOtpChallengeRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<OtpChallenge> findAndLock(PhoneNumber phone) {
        return jdbc.sql("""
                        select code_hash, sent_at, expires_at, attempts, sends_in_window, window_started_at
                        from otp_challenges
                        where phone = :phone
                        for update
                        """)
                .param("phone", phone.value())
                .query((rs, rowNum) -> OtpChallenge.restore(
                        phone,
                        rs.getBytes("code_hash"),
                        SqlTime.instant(rs, "sent_at"),
                        SqlTime.instant(rs, "expires_at"),
                        rs.getInt("attempts"),
                        rs.getInt("sends_in_window"),
                        SqlTime.instant(rs, "window_started_at")))
                .optional();
    }

    @Override
    public boolean tryAdd(OtpChallenge challenge) {
        int inserted = jdbc.sql("""
                        insert into otp_challenges (phone, code_hash, sent_at, expires_at, attempts,
                                                    sends_in_window, window_started_at)
                        values (:phone, :codeHash, :sentAt, :expiresAt, :attempts, :sendsInWindow, :windowStartedAt)
                        on conflict (phone) do nothing
                        """)
                .params(params(challenge))
                .update();
        return inserted == 1;
    }

    @Override
    public void update(OtpChallenge challenge) {
        jdbc.sql("""
                        update otp_challenges
                        set code_hash = :codeHash, sent_at = :sentAt, expires_at = :expiresAt, attempts = :attempts,
                            sends_in_window = :sendsInWindow, window_started_at = :windowStartedAt
                        where phone = :phone
                        """)
                .params(params(challenge))
                .update();
    }

    @Override
    public void remove(PhoneNumber phone) {
        jdbc.sql("delete from otp_challenges where phone = :phone")
                .param("phone", phone.value())
                .update();
    }

    @Override
    public int removeFinished(Instant now) {
        return jdbc.sql("""
                        delete from otp_challenges
                        where expires_at < :now and window_started_at < :windowCutoff
                        """)
                .param("now", SqlTime.toSql(now))
                .param("windowCutoff", SqlTime.toSql(now.minus(OtpChallenge.WINDOW)))
                .update();
    }

    private static Map<String, Object> params(OtpChallenge challenge) {
        return Map.of(
                "phone", challenge.phone().value(),
                "codeHash", challenge.codeHash(),
                "sentAt", SqlTime.toSql(challenge.sentAt()),
                "expiresAt", SqlTime.toSql(challenge.expiresAt()),
                "attempts", challenge.wrongAttempts(),
                "sendsInWindow", challenge.sendsInWindow(),
                "windowStartedAt", SqlTime.toSql(challenge.windowStartedAt()));
    }
}
