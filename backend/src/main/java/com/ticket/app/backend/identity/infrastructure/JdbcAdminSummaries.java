package com.ticket.app.backend.identity.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.admin.domain.AdminRole;
import com.ticket.app.backend.identity.domain.AdminSummaries;
import com.ticket.app.backend.identity.domain.AdminSummary;
import com.ticket.app.backend.shared.domain.EmailAddress;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcAdminSummaries implements AdminSummaries {

    private static final String SELECT = """
            select a.id, a.name, a.email, a.role, a.created_at, adder.name as added_by,
                   case when p.admin_id is null then 'NONE'
                        when p.must_change then 'TEMPORARY'
                        else 'OWN' end as password
            from admins a
            left join admins adder on adder.id = a.added_by
            left join admin_passwords p on p.admin_id = a.id
            where a.email is not null and a.removed_at is null
            """;

    private final JdbcClient jdbc;

    JdbcAdminSummaries(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public List<AdminSummary> all() {
        return jdbc.sql(SELECT + "order by a.created_at, a.name")
                .query(JdbcAdminSummaries::summary)
                .list();
    }

    @Override
    public Optional<AdminSummary> find(AdminId id) {
        return jdbc.sql(SELECT + "and a.id = :id")
                .param("id", id.value())
                .query(JdbcAdminSummaries::summary)
                .optional();
    }

    private static AdminSummary summary(ResultSet rs, int rowNum) throws SQLException {
        return new AdminSummary(
                new AdminId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                new EmailAddress(rs.getString("email")),
                AdminRole.valueOf(rs.getString("role").toUpperCase(Locale.ROOT)),
                SqlTime.instant(rs, "created_at"),
                rs.getString("added_by"),
                AdminSummary.PasswordState.valueOf(rs.getString("password")));
    }
}
