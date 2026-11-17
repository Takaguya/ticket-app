package com.ticket.app.backend.identity.repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.identity.model.BuyerSession;
import com.ticket.app.backend.identity.model.TokenHash;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcBuyerSessionRepository implements BuyerSessionRepository {

    private final JdbcClient jdbc;

    JdbcBuyerSessionRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(BuyerSession session) {
        jdbc.sql("""
                        insert into buyer_sessions (token_hash, buyer_id, expires_at)
                        values (:tokenHash, :buyerId, :expiresAt)
                        """)
                .param("tokenHash", session.tokenHash().bytes())
                .param("buyerId", session.buyerId().value())
                .param("expiresAt", SqlTime.toSql(session.expiresAt()))
                .update();
    }

    @Override
    public Optional<BuyerSession> find(TokenHash tokenHash) {
        return jdbc.sql("select buyer_id, expires_at from buyer_sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .query((rs, rowNum) -> new BuyerSession(
                        tokenHash,
                        new BuyerId(rs.getObject("buyer_id", UUID.class)),
                        SqlTime.instant(rs, "expires_at")))
                .optional();
    }

    @Override
    public void remove(TokenHash tokenHash) {
        jdbc.sql("delete from buyer_sessions where token_hash = :tokenHash")
                .param("tokenHash", tokenHash.bytes())
                .update();
    }

    @Override
    public int removeExpired(Instant now) {
        return jdbc.sql("delete from buyer_sessions where expires_at < :now")
                .param("now", SqlTime.toSql(now))
                .update();
    }
}
