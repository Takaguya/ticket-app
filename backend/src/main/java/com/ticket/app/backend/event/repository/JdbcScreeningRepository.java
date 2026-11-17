package com.ticket.app.backend.event.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.Screening;
import com.ticket.app.backend.event.model.SeatLayout;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Screenings in {@code screenings}; they go with their event. */
@Repository
class JdbcScreeningRepository implements ScreeningRepository {

    private static final String SELECT_SCREENINGS = """
            select event_id, film_title, rating, genre, runtime_minutes, hall, hall_size
            from screenings
            """;

    private final JdbcClient jdbc;

    JdbcScreeningRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(Screening screening) {
        jdbc.sql("""
                        insert into screenings (event_id, film_title, rating, genre, runtime_minutes, hall, hall_size)
                        values (:eventId, :title, :rating, :genre, :runtime, :hall, :size)
                        """)
                .param("eventId", screening.eventId().value())
                .param("title", screening.filmTitle())
                .param("rating", screening.rating())
                .param("genre", screening.genre())
                .param("runtime", screening.runtimeMinutes())
                .param("hall", screening.hall())
                .param("size", screening.layout().code())
                .update();
    }

    @Override
    public Optional<Screening> find(EventId eventId) {
        return jdbc.sql(SELECT_SCREENINGS + "where event_id = :eventId")
                .param("eventId", eventId.value())
                .query(JdbcScreeningRepository::screening)
                .optional();
    }

    @Override
    public Map<EventId, Screening> findAll(Collection<EventId> eventIds) {
        if (eventIds.isEmpty()) {
            return Map.of();
        }
        Map<EventId, Screening> screenings = new HashMap<>();
        jdbc.sql(SELECT_SCREENINGS + "where event_id in (:eventIds)")
                .param("eventIds", eventIds.stream().map(EventId::value).toList())
                .query(JdbcScreeningRepository::screening)
                .list()
                .forEach(screening -> screenings.put(screening.eventId(), screening));
        return screenings;
    }

    private static Screening screening(ResultSet rs, int rowNum) throws SQLException {
        return new Screening(
                new EventId(rs.getObject("event_id", UUID.class)),
                rs.getString("film_title"),
                rs.getString("rating"),
                rs.getString("genre"),
                rs.getInt("runtime_minutes"),
                rs.getString("hall"),
                SeatLayout.hallFromCode(rs.getString("hall_size")));
    }
}
