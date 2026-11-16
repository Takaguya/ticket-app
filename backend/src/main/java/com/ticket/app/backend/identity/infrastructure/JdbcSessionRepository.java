package com.ticket.app.backend.identity.infrastructure;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.identity.domain.Session;
import com.ticket.app.backend.identity.domain.SessionRepository;
import com.ticket.app.backend.identity.domain.TokenHash;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcSessionRepository implements SessionRepository {

    private final JdbcClient jdbc;

    JdbcSessionRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(Session session) {
        jdbc.sql("""
                        insert into sessions (token_hash, member_id, expires_at)
                        values (:tokenHash, :staffId, :expiresAt)
                        """)
                .param("tokenHash", session.tokenHash().bytes())
                .param("staffId", session.staffId().value())
                .param("expiresAt", SqlTime.toSql(session.expiresAt()))
                .update();
    }

    @Override
    public Optional<Session> find(TokenHash tokenHash) {
        return jdbc.sql("select member_id, expires_at from sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .query((rs, rowNum) -> new Session(
                        tokenHash,
                        new StaffId(rs.getObject("member_id", UUID.class)),
                        SqlTime.instant(rs, "expires_at")))
                .optional();
    }

    @Override
    public void remove(TokenHash tokenHash) {
        jdbc.sql("delete from sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .update();
    }

    @Override
    public void removeAllOf(StaffId staffId) {
        jdbc.sql("delete from sessions where member_id = :staffId")
                .param("staffId", staffId.value())
                .update();
    }

    @Override
    public int removeExpired(Instant now) {
        return jdbc.sql("delete from sessions where expires_at < :now")
                .param("now", SqlTime.toSql(now))
                .update();
    }
}
