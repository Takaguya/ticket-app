package com.ticket.app.backend.event.repository;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventImage;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Events' cover images in {@code event_images}; they go with their event. */
@Repository
class JdbcEventImageRepository implements EventImageRepository {

    private final JdbcClient jdbc;

    JdbcEventImageRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<EventImage> find(EventId eventId) {
        return jdbc.sql("select event_id, content_type, data, updated_at from event_images where event_id = :eventId")
                .param("eventId", eventId.value())
                .query((rs, rowNum) -> new EventImage(
                        new EventId(rs.getObject("event_id", UUID.class)),
                        rs.getString("content_type"),
                        rs.getBytes("data"),
                        SqlTime.instant(rs, "updated_at")))
                .optional();
    }

    @Override
    public Map<EventId, Long> findVersions(Collection<EventId> eventIds) {
        if (eventIds.isEmpty()) {
            return Map.of();
        }
        List<UUID> ids = eventIds.stream().map(EventId::value).toList();
        Map<EventId, Long> versions = new HashMap<>();
        // The picture's bytes are not selected: a list of events must not read them.
        jdbc.sql("select event_id, updated_at from event_images where event_id in (:eventIds)")
                .param("eventIds", ids)
                .query(rs -> {
                    versions.put(new EventId(rs.getObject("event_id", UUID.class)),
                            SqlTime.instant(rs, "updated_at").toEpochMilli());
                });
        return versions;
    }

    @Override
    public void save(EventImage image) {
        jdbc.sql("""
                        insert into event_images (event_id, content_type, data, updated_at)
                        values (:eventId, :contentType, :data, :updatedAt)
                        on conflict (event_id) do update set
                            content_type = excluded.content_type, data = excluded.data,
                            updated_at = excluded.updated_at
                        """)
                .param("eventId", image.eventId().value())
                .param("contentType", image.contentType())
                .param("data", image.data())
                .param("updatedAt", SqlTime.toSql(image.updatedAt()))
                .update();
    }

    @Override
    public void delete(EventId eventId) {
        jdbc.sql("delete from event_images where event_id = :eventId")
                .param("eventId", eventId.value())
                .update();
    }
}
