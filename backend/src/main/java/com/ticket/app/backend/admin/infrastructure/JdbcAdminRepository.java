package com.ticket.app.backend.admin.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.admin.domain.AdminRepository;
import com.ticket.app.backend.admin.domain.AdminRole;
import com.ticket.app.backend.shared.domain.EmailAddress;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcAdminRepository implements AdminRepository {

    private final JdbcClient jdbc;

    JdbcAdminRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<Admin> find(AdminId id) {
        return jdbc.sql("""
                        select id, name, email, role from admins
                        where id = :id and email is not null and removed_at is null
                        """)
                .param("id", id.value())
                .query(JdbcAdminRepository::admin)
                .optional();
    }

    @Override
    public Optional<Admin> findByEmail(EmailAddress email) {
        return jdbc.sql("select id, name, email, role from admins where email = :email and removed_at is null")
                .param("email", email.value())
                .query(JdbcAdminRepository::admin)
                .optional();
    }

    @Override
    public void add(Admin admin, AdminId addedBy) {
        jdbc.sql("""
                        insert into admins (id, name, email, role, added_by)
                        values (:id, :name, :email, :role, :addedBy)
                        """)
                .param("id", admin.id().value())
                .param("name", admin.name())
                .param("email", admin.email().value())
                .param("role", admin.role().name().toLowerCase(Locale.ROOT))
                .param("addedBy", addedBy == null ? null : addedBy.value())
                .update();
    }

    @Override
    public boolean remove(AdminId id, AdminId removedBy, Instant now) {
        return jdbc.sql("""
                        update admins set removed_at = :now, removed_by = :removedBy
                        where id = :id and removed_at is null
                        """)
                .param("id", id.value())
                .param("removedBy", removedBy.value())
                .param("now", SqlTime.toSql(now))
                .update() == 1;
    }

    @Override
    public boolean changeRole(AdminId id, AdminRole role) {
        return jdbc.sql("update admins set role = :role where id = :id and removed_at is null")
                .param("id", id.value())
                .param("role", role.name().toLowerCase(Locale.ROOT))
                .update() == 1;
    }

    private static Admin admin(ResultSet rs, int rowNum) throws SQLException {
        return new Admin(
                new AdminId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                new EmailAddress(rs.getString("email")),
                AdminRole.valueOf(rs.getString("role").toUpperCase(Locale.ROOT)));
    }
}
