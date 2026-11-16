package com.ticket.app.backend.identity.infrastructure;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.identity.domain.RegistrationToken;
import com.ticket.app.backend.identity.domain.RegistrationTokenRepository;
import com.ticket.app.backend.identity.domain.TokenHash;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcRegistrationTokenRepository implements RegistrationTokenRepository {

    private final JdbcClient jdbc;

    JdbcRegistrationTokenRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(RegistrationToken registration) {
        jdbc.sql("""
                        insert into registration_tokens (token_hash, phone, expires_at, attempts)
                        values (:tokenHash, :phone, :expiresAt, :attempts)
                        """)
                .param("tokenHash", registration.tokenHash().bytes())
                .param("phone", registration.phone().value())
                .param("expiresAt", SqlTime.toSql(registration.expiresAt()))
                .param("attempts", registration.wrongJoinCodes())
                .update();
    }

    @Override
    public Optional<RegistrationToken> findAndLock(TokenHash tokenHash) {
        return jdbc.sql("""
                        select phone, expires_at, attempts
                        from registration_tokens
                        where token_hash = :tokenHash
                        for update
                        """)
                .param("tokenHash", tokenHash.bytes())
                .query((rs, rowNum) -> RegistrationToken.restore(
                        tokenHash,
                        new PhoneNumber(rs.getString("phone")),
                        SqlTime.instant(rs, "expires_at"),
                        rs.getInt("attempts")))
                .optional();
    }

    @Override
    public void update(RegistrationToken registration) {
        jdbc.sql("update registration_tokens set attempts = :attempts where token_hash = :tokenHash")
                .param("attempts", registration.wrongJoinCodes())
                .param("tokenHash", registration.tokenHash().bytes())
                .update();
    }

    @Override
    public void remove(TokenHash tokenHash) {
        jdbc.sql("delete from registration_tokens where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .update();
    }

    @Override
    public void removeAllFor(PhoneNumber phone) {
        jdbc.sql("delete from registration_tokens where phone = :phone")
                .param("phone", phone.value())
                .update();
    }

    @Override
    public int removeExpired(Instant now) {
        return jdbc.sql("delete from registration_tokens where expires_at < :now")
                .param("now", SqlTime.toSql(now))
                .update();
    }
}
