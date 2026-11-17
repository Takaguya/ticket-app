package com.ticket.app.backend.business.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.business.model.Business;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.business.model.BusinessStatus;
import com.ticket.app.backend.business.model.BusinessType;
import com.ticket.app.backend.business.model.JoinCode;
import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.business.model.StaffRole;
import com.ticket.app.backend.shared.model.PhoneNumber;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcStaffRepository implements StaffRepository {

    private static final String SELECT_CURRENT = """
            select m.id, m.name, m.phone, m.role,
                   b.id as business_id, b.name as business_name, b.type as business_type, b.join_code,
                   b.status as business_status
            from staff_members m
            join businesses b on b.id = m.business_id
            where m.removed_at is null
            """;

    private final JdbcClient jdbc;

    JdbcStaffRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<StaffMember> findCurrent(StaffId id) {
        return jdbc.sql(SELECT_CURRENT + "and m.id = :id")
                .param("id", id.value())
                .query(JdbcStaffRepository::member)
                .optional();
    }

    @Override
    public Optional<StaffMember> findCurrentByPhone(PhoneNumber phone) {
        return jdbc.sql(SELECT_CURRENT + "and m.phone = :phone")
                .param("phone", phone.value())
                .query(JdbcStaffRepository::member)
                .optional();
    }

    @Override
    public List<StaffMember> findCurrentByBusiness(BusinessId businessId) {
        return jdbc.sql(SELECT_CURRENT + """
                        and m.business_id = :businessId
                        order by m.role = 'owner' desc, m.created_at, m.name
                        """)
                .param("businessId", businessId.value())
                .query(JdbcStaffRepository::member)
                .list();
    }

    @Override
    public void markRemoved(StaffId id, Instant at) {
        jdbc.sql("update staff_members set removed_at = :at where id = :id and removed_at is null")
                .param("at", SqlTime.toSql(at))
                .param("id", id.value())
                .update();
    }

    @Override
    public boolean tryAdd(StaffMember member) {
        int inserted = jdbc.sql("""
                        insert into staff_members (id, business_id, name, phone, role)
                        values (:id, :businessId, :name, :phone, :role)
                        on conflict (phone) where removed_at is null do nothing
                        """)
                .param("id", member.id().value())
                .param("businessId", member.businessId().value())
                .param("name", member.name())
                .param("phone", member.phone().value())
                .param("role", member.role().code())
                .update();
        return inserted == 1;
    }

    private static StaffMember member(ResultSet rs, int rowNum) throws SQLException {
        Business business = new Business(
                new BusinessId(rs.getObject("business_id", UUID.class)),
                rs.getString("business_name"),
                BusinessType.fromCode(rs.getString("business_type")),
                new JoinCode(rs.getString("join_code")),
                BusinessStatus.fromCode(rs.getString("business_status")));
        return new StaffMember(
                new StaffId(rs.getObject("id", UUID.class)),
                business,
                rs.getString("name"),
                new PhoneNumber(rs.getString("phone")),
                StaffRole.fromCode(rs.getString("role")));
    }
}
