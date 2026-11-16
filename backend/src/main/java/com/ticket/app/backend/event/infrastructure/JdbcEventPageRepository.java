package com.ticket.app.backend.event.infrastructure;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.EventPageRepository;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Event pages in {@code event_pages}; they go with their event. */
@Repository
class JdbcEventPageRepository implements EventPageRepository {

    private static final String SELECT_PAGES = """
            select event_id, venue_detail, about, policy, ticket_type_notes
            from event_pages
            """;

    /** Notes are free text and may hold commas, so they are joined with the ASCII unit separator. */
    private static final String NOTE_SEPARATOR = "\u001f";

    private final JdbcClient jdbc;

    JdbcEventPageRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<EventPage> find(EventId eventId) {
        return jdbc.sql(SELECT_PAGES + "where event_id = :eventId")
                .param("eventId", eventId.value())
                .query(JdbcEventPageRepository::page)
                .optional();
    }

    @Override
    public Map<EventId, EventPage> findAll(Collection<EventId> eventIds) {
        if (eventIds.isEmpty()) {
            return Map.of();
        }
        List<UUID> ids = eventIds.stream().map(EventId::value).toList();
        Map<EventId, EventPage> pages = new HashMap<>();
        jdbc.sql(SELECT_PAGES + "where event_id in (:eventIds)")
                .param("eventIds", ids)
                .query(JdbcEventPageRepository::page)
                .list()
                .forEach(page -> pages.put(page.eventId(), page));
        return pages;
    }

    @Override
    public void save(EventPage page) {
        jdbc.sql("""
                        insert into event_pages (event_id, venue_detail, about, policy, ticket_type_notes)
                        values (:eventId, :venueDetail, :about, :policy, string_to_array(:notes, chr(31)))
                        on conflict (event_id) do update set
                            venue_detail = excluded.venue_detail, about = excluded.about, policy = excluded.policy,
                            ticket_type_notes = excluded.ticket_type_notes
                        """)
                .param("eventId", page.eventId().value())
                .param("venueDetail", page.venueDetail())
                .param("about", page.about())
                .param("policy", page.policy())
                .param("notes", String.join(NOTE_SEPARATOR, page.ticketTypeNotes()))
                .update();
    }

    private static EventPage page(ResultSet rs, int rowNum) throws SQLException {
        Array notes = rs.getArray("ticket_type_notes");
        return new EventPage(
                new EventId(rs.getObject("event_id", UUID.class)),
                rs.getString("venue_detail"),
                rs.getString("about"),
                rs.getString("policy"),
                notes == null ? List.of() : List.of((String[]) notes.getArray()));
    }
}
