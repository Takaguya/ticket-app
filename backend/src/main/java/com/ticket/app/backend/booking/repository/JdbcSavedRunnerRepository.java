package com.ticket.app.backend.booking.repository;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** The runner each buyer saved, in {@code saved_runners}. */
@Repository
class JdbcSavedRunnerRepository implements SavedRunnerRepository {

    private final JdbcClient jdbc;

    JdbcSavedRunnerRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<Runner> find(BuyerId buyer) {
        return jdbc.sql("select " + RunnerColumns.SELECT + " from saved_runners where buyer_id = :buyerId")
                .param("buyerId", buyer.value())
                .query((rs, rowNum) -> RunnerColumns.read(rs))
                .optional();
    }

    @Override
    public void save(BuyerId buyer, Runner runner, Instant savedAt) {
        RunnerColumns.bind(jdbc.sql("""
                        insert into saved_runners (buyer_id, name, phone, email, gender, age, nationality,
                                                   emergency_name, emergency_phone, shirt_size, saved_at)
                        values (:buyerId, :name, :phone, :email, :gender, :age, :nationality,
                                :emergencyName, :emergencyPhone, :shirtSize, :savedAt)
                        on conflict (buyer_id) do update set
                            name = excluded.name, phone = excluded.phone, email = excluded.email,
                            gender = excluded.gender, age = excluded.age, nationality = excluded.nationality,
                            emergency_name = excluded.emergency_name, emergency_phone = excluded.emergency_phone,
                            shirt_size = excluded.shirt_size, saved_at = excluded.saved_at
                        """), runner)
                .param("buyerId", buyer.value())
                .param("savedAt", SqlTime.toSql(savedAt))
                .update();
    }
}
