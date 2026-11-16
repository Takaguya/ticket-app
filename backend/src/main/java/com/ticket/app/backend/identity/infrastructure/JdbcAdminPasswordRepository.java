package com.ticket.app.backend.identity.infrastructure;

import java.util.Optional;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.identity.domain.AdminPassword;
import com.ticket.app.backend.identity.domain.AdminPasswordRepository;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcAdminPasswordRepository implements AdminPasswordRepository {

    private final JdbcClient jdbc;

    JdbcAdminPasswordRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<AdminPassword> findAndLock(AdminId adminId) {
        return jdbc.sql("""
                        select password_hash, must_change, wrong_attempts, locked_until
                        from admin_passwords
                        where admin_id = :adminId
                        for update
                        """)
                .param("adminId", adminId.value())
                .query((rs, rowNum) -> AdminPassword.restore(
                        adminId,
                        rs.getString("password_hash"),
                        rs.getBoolean("must_change"),
                        rs.getInt("wrong_attempts"),
                        SqlTime.instant(rs, "locked_until")))
                .optional();
    }

    @Override
    public void save(AdminPassword password) {
        jdbc.sql("""
                        insert into admin_passwords (admin_id, password_hash, must_change, wrong_attempts, locked_until)
                        values (:adminId, :hash, :mustChange, :wrongAttempts, :lockedUntil)
                        on conflict (admin_id) do update
                        set password_hash = excluded.password_hash,
                            must_change = excluded.must_change,
                            wrong_attempts = excluded.wrong_attempts,
                            locked_until = excluded.locked_until
                        """)
                .param("adminId", password.adminId().value())
                .param("hash", password.hash())
                .param("mustChange", password.mustChange())
                .param("wrongAttempts", password.wrongAttempts())
                .param("lockedUntil", SqlTime.toSql(password.lockedUntil().orElse(null)))
                .update();
    }

    @Override
    public boolean mustChange(AdminId adminId) {
        return jdbc.sql("select coalesce(bool_or(must_change), false) from admin_passwords where admin_id = :adminId")
                .param("adminId", adminId.value())
                .query(Boolean.class)
                .single();
    }

    @Override
    public void remove(AdminId adminId) {
        jdbc.sql("delete from admin_passwords where admin_id = :adminId")
                .param("adminId", adminId.value())
                .update();
    }

    @Override
    public int count() {
        return jdbc.sql("select count(*) from admin_passwords").query(Integer.class).single();
    }
}
