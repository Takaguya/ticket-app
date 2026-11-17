package com.ticket.app.backend.event.repository;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.SeatLayout;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Bus trips in {@code bus_trips}; they go with their event. */
@Repository
class JdbcBusTripRepository implements BusTripRepository {

    private static final String SELECT_TRIPS = """
            select event_id, origin, destination, duration_minutes, coach_type, amenities
            from bus_trips
            """;

    /** Amenities are free text and may hold commas, so they are joined with the ASCII unit separator. */
    private static final String SEPARATOR = "\u001f";

    private final JdbcClient jdbc;

    JdbcBusTripRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(BusTrip trip) {
        jdbc.sql("""
                        insert into bus_trips (event_id, origin, destination, duration_minutes, coach_type, amenities)
                        values (:eventId, :origin, :destination, :duration, :coach, string_to_array(:amenities, chr(31)))
                        """)
                .param("eventId", trip.eventId().value())
                .param("origin", trip.origin())
                .param("destination", trip.destination())
                .param("duration", trip.durationMinutes())
                .param("coach", trip.layout().code())
                .param("amenities", String.join(SEPARATOR, trip.amenities()))
                .update();
    }

    @Override
    public Optional<BusTrip> find(EventId eventId) {
        return jdbc.sql(SELECT_TRIPS + "where event_id = :eventId")
                .param("eventId", eventId.value())
                .query(JdbcBusTripRepository::trip)
                .optional();
    }

    @Override
    public Map<EventId, BusTrip> findAll(Collection<EventId> eventIds) {
        if (eventIds.isEmpty()) {
            return Map.of();
        }
        Map<EventId, BusTrip> trips = new HashMap<>();
        jdbc.sql(SELECT_TRIPS + "where event_id in (:eventIds)")
                .param("eventIds", eventIds.stream().map(EventId::value).toList())
                .query(JdbcBusTripRepository::trip)
                .list()
                .forEach(trip -> trips.put(trip.eventId(), trip));
        return trips;
    }

    private static BusTrip trip(ResultSet rs, int rowNum) throws SQLException {
        Array amenities = rs.getArray("amenities");
        return new BusTrip(
                new EventId(rs.getObject("event_id", UUID.class)),
                rs.getString("origin"),
                rs.getString("destination"),
                rs.getInt("duration_minutes"),
                SeatLayout.coachFromCode(rs.getString("coach_type")),
                amenities == null ? List.of() : List.of((String[]) amenities.getArray()));
    }
}
