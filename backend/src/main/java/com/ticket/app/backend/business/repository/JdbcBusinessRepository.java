package com.ticket.app.backend.business.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.business.model.Business;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.business.model.BusinessStatus;
import com.ticket.app.backend.business.model.BusinessType;
import com.ticket.app.backend.business.model.JoinCode;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcBusinessRepository implements BusinessRepository {

    private static final String SELECT_BUSINESSES = "select id, name, type, join_code, status from businesses ";

    private final JdbcClient jdbc;

    JdbcBusinessRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<Business> find(BusinessId id) {
        return jdbc.sql(SELECT_BUSINESSES + "where id = :id")
                .param("id", id.value())
                .query(JdbcBusinessRepository::business)
                .optional();
    }

    @Override
    public Optional<Business> findAndLock(BusinessId id) {
        return jdbc.sql(SELECT_BUSINESSES + "where id = :id for update")
                .param("id", id.value())
                .query(JdbcBusinessRepository::business)
                .optional();
    }

    @Override
    public Optional<Business> findByJoinCode(JoinCode joinCode) {
        return jdbc.sql(SELECT_BUSINESSES + "where join_code = :joinCode")
                .param("joinCode", joinCode.digits())
                .query(JdbcBusinessRepository::business)
                .optional();
    }

    @Override
    public boolean tryAdd(Business business) {
        // "do nothing" instead of an error keeps the transaction usable for another try.
        int inserted = jdbc.sql("""
                        insert into businesses (id, name, type, join_code, status)
                        values (:id, :name, :type, :joinCode, :status)
                        on conflict (join_code) do nothing
                        """)
                .param("id", business.id().value())
                .param("name", business.name())
                .param("type", business.type().code())
                .param("joinCode", business.joinCode().digits())
                .param("status", business.status().code())
                .update();
        return inserted == 1;
    }

    @Override
    public boolean tryChangeJoinCode(BusinessId businessId, JoinCode joinCode) {
        // The check keeps the transaction usable when the code is taken. Two businesses
        // drawing the same new code at the same moment would still hit the unique index.
        int updated = jdbc.sql("""
                        update businesses set join_code = :joinCode
                        where id = :id
                          and not exists (select 1 from businesses where join_code = :joinCode)
                        """)
                .param("joinCode", joinCode.digits())
                .param("id", businessId.value())
                .update();
        return updated == 1;
    }

    @Override
    public void updateStatus(Business business) {
        jdbc.sql("update businesses set status = :status where id = :id")
                .param("status", business.status().code())
                .param("id", business.id().value())
                .update();
    }

    private static Business business(ResultSet rs, int rowNum) throws SQLException {
        return new Business(
                new BusinessId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                BusinessType.fromCode(rs.getString("type")),
                new JoinCode(rs.getString("join_code")),
                BusinessStatus.fromCode(rs.getString("status")));
    }
}
