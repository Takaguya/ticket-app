package com.ticket.app.backend.booking.repository;

import java.sql.ResultSet;
import java.sql.SQLException;

import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.booking.model.ShirtSize;
import com.ticket.app.backend.buyer.model.Gender;
import com.ticket.app.backend.shared.model.EmailAddress;
import com.ticket.app.backend.shared.model.PhoneNumber;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * The runner's columns, which {@code booking_runners} and {@code saved_runners} share:
 * reading them into a {@link Runner}, and binding a {@link Runner} to a statement.
 */
final class RunnerColumns {

    /** The columns to select, for the runner's own table. */
    static final String SELECT =
            "name, phone, email, gender, age, nationality, emergency_name, emergency_phone, shirt_size";

    private RunnerColumns() {
    }

    static Runner read(ResultSet rs) throws SQLException {
        String email = rs.getString("email");
        return new Runner(
                rs.getString("name"),
                new PhoneNumber(rs.getString("phone")),
                email == null ? null : new EmailAddress(email),
                Gender.fromCode(rs.getString("gender")),
                rs.getInt("age"),
                rs.getString("nationality"),
                rs.getString("emergency_name"),
                new PhoneNumber(rs.getString("emergency_phone")),
                ShirtSize.fromCode(rs.getString("shirt_size")));
    }

    /**
     * Binds {@code :name}, {@code :phone}, {@code :email}, {@code :gender}, {@code :age},
     * {@code :nationality}, {@code :emergencyName}, {@code :emergencyPhone} and {@code :shirtSize}.
     */
    static JdbcClient.StatementSpec bind(JdbcClient.StatementSpec statement, Runner runner) {
        return statement
                .param("name", runner.name())
                .param("phone", runner.phone().value())
                .param("email", runner.email() == null ? null : runner.email().value())
                .param("gender", runner.gender().code())
                .param("age", runner.age())
                .param("nationality", runner.nationality())
                .param("emergencyName", runner.emergencyName())
                .param("emergencyPhone", runner.emergencyPhone().value())
                .param("shirtSize", runner.shirtSize().code());
    }
}
