package com.ticket.app.backend.buyer.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.buyer.model.Gender;
import com.ticket.app.backend.shared.model.EmailAddress;
import com.ticket.app.backend.shared.model.PhoneNumber;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
class JdbcBuyerRepository implements BuyerRepository {

    private static final String SELECT_BUYERS = "select id, name, phone, gender, date_of_birth, email from buyers ";

    private final JdbcClient jdbc;

    JdbcBuyerRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<Buyer> find(BuyerId id) {
        return jdbc.sql(SELECT_BUYERS + "where id = :id")
                .param("id", id.value())
                .query(JdbcBuyerRepository::buyer)
                .optional();
    }

    @Override
    public Optional<Buyer> findByPhone(PhoneNumber phone) {
        return jdbc.sql(SELECT_BUYERS + "where phone = :phone")
                .param("phone", phone.value())
                .query(JdbcBuyerRepository::buyer)
                .optional();
    }

    @Override
    public boolean tryAdd(Buyer buyer) {
        int inserted = jdbc.sql("""
                        insert into buyers (id, name, phone, gender, date_of_birth, email)
                        values (:id, :name, :phone, :gender, :dateOfBirth, :email)
                        on conflict (phone) do nothing
                        """)
                .param("id", buyer.id().value())
                .param("name", buyer.name())
                .param("phone", buyer.phone().value())
                .param("gender", buyer.gender().code())
                .param("dateOfBirth", buyer.dateOfBirth())
                .param("email", buyer.email().map(EmailAddress::value).orElse(null))
                .update();
        return inserted == 1;
    }

    private static Buyer buyer(ResultSet rs, int rowNum) throws SQLException {
        String email = rs.getString("email");
        return Buyer.restore(
                new BuyerId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                new PhoneNumber(rs.getString("phone")),
                Gender.fromCode(rs.getString("gender")),
                rs.getObject("date_of_birth", LocalDate.class),
                email == null ? null : new EmailAddress(email));
    }
}
