package com.ticket.app.backend.identity.infrastructure;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.identity.domain.AdminSession;
import com.ticket.app.backend.identity.domain.AdminSessionRepository;
import com.ticket.app.backend.identity.domain.TokenHash;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcAdminSessionRepository implements AdminSessionRepository {

    private final JdbcClient jdbc;

    JdbcAdminSessionRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(AdminSession session) {
        jdbc.sql("""
                        insert into admin_sessions (token_hash, admin_id, expires_at)
                        values (:tokenHash, :adminId, :expiresAt)
                        """)
                .param("tokenHash", session.tokenHash().bytes())
                .param("adminId", session.adminId().value())
                .param("expiresAt", SqlTime.toSql(session.expiresAt()))
                .update();
    }

    @Override
    public Optional<AdminSession> find(TokenHash tokenHash) {
        return jdbc.sql("select admin_id, expires_at from admin_sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .query((rs, rowNum) -> new AdminSession(
                        tokenHash,
                        new AdminId(rs.getObject("admin_id", UUID.class)),
                        SqlTime.instant(rs, "expires_at")))
                .optional();
    }

    @Override
    public void remove(TokenHash tokenHash) {
        jdbc.sql("delete from admin_sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .update();
    }

    @Override
    public void removeAllFor(AdminId adminId) {
        jdbc.sql("delete from admin_sessions where admin_id = :adminId")
                .param("adminId", adminId.value())
                .update();
    }

    @Override
    public void removeAllForExcept(AdminId adminId, TokenHash keep) {
        jdbc.sql("delete from admin_sessions where admin_id = :adminId and token_hash <> :keep")
                .param("adminId", adminId.value())
                .param("keep", keep.bytes())
                .update();
    }

    @Override
    public int removeExpired(Instant now) {
        return jdbc.sql("delete from admin_sessions where expires_at < :now")
                .param("now", SqlTime.toSql(now))
                .update();
    }
}
