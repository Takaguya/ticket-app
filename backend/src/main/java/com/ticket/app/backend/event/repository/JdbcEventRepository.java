package com.ticket.app.backend.event.repository;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Events in {@code events}, their ticket types in {@code ticket_types}. Start times
 * are stored as instants and turned back into venue-local times with Pin's time zone.
 */
@Repository
class JdbcEventRepository implements EventRepository {

    private static final String SELECT_EVENTS =
            "select id, business_id, name, starts_at, venue, commission_rate, approved_at, kind from events ";

    private final JdbcClient jdbc;
    private final ZoneId zone;

    JdbcEventRepository(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.zone = clock.getZone();
    }

    @Override
    public void add(Event event) {
        jdbc.sql("""
                        insert into events (id, business_id, name, starts_at, venue, commission_rate, approved_at, kind)
                        values (:id, :businessId, :name, :startsAt, :venue, :commissionRate, :approvedAt, :kind)
                        """)
                .param("id", event.id().value())
                .param("businessId", event.businessId().value())
                .param("name", event.name())
                .param("startsAt", event.startsAt().atZone(zone).toOffsetDateTime())
                .param("venue", event.venue())
                .param("commissionRate", event.commissionRate())
                .param("approvedAt", event.approvedAt().map(SqlTime::toSql).orElse(null))
                .param("kind", event.kind().code())
                .update();

        List<TicketType> types = event.ticketTypes();
        for (int position = 0; position < types.size(); position++) {
            TicketType type = types.get(position);
            jdbc.sql("""
                            insert into ticket_types (event_id, position, name, price_cents, quantity)
                            values (:eventId, :position, :name, :priceCents, :quantity)
                            """)
                    .param("eventId", event.id().value())
                    .param("position", position)
                    .param("name", type.name())
                    .param("priceCents", type.price().cents())
                    .param("quantity", type.quantity())
                    .update();
        }
    }

    @Override
    public Optional<Event> find(EventId id) {
        return findOne(id, "");
    }

    @Override
    public Optional<Event> findAndLock(EventId id) {
        return findOne(id, " for update");
    }

    @Override
    public List<Event> findByBusiness(BusinessId businessId) {
        List<EventRow> rows = jdbc.sql(SELECT_EVENTS + "where business_id = :businessId order by starts_at")
                .param("businessId", businessId.value())
                .query(this::eventRow)
                .list();
        Map<UUID, List<TicketType>> types = ticketTypes(jdbc.sql("""
                        select t.event_id, t.name, t.price_cents, t.quantity
                        from ticket_types t
                        join events e on e.id = t.event_id
                        where e.business_id = :id
                        order by t.event_id, t.position
                        """).param("id", businessId.value()));
        return rows.stream().map(row -> row.toEvent(types.getOrDefault(row.id(), List.of()))).toList();
    }

    @Override
    public List<Event> findAllById(Collection<EventId> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }
        List<UUID> uuids = ids.stream().map(EventId::value).toList();
        List<EventRow> rows = jdbc.sql(SELECT_EVENTS + "where id in (:ids) order by starts_at")
                .param("ids", uuids)
                .query(this::eventRow)
                .list();
        Map<UUID, List<TicketType>> types = ticketTypes(jdbc.sql("""
                        select event_id, name, price_cents, quantity
                        from ticket_types
                        where event_id in (:ids)
                        order by event_id, position
                        """).param("ids", uuids));
        return rows.stream().map(row -> row.toEvent(types.getOrDefault(row.id(), List.of()))).toList();
    }

    @Override
    public List<Event> findAll() {
        List<EventRow> rows = jdbc.sql(SELECT_EVENTS + "order by starts_at")
                .query(this::eventRow)
                .list();
        Map<UUID, List<TicketType>> types = ticketTypes(jdbc.sql("""
                        select event_id, name, price_cents, quantity
                        from ticket_types
                        order by event_id, position
                        """));
        return rows.stream().map(row -> row.toEvent(types.getOrDefault(row.id(), List.of()))).toList();
    }

    @Override
    public void updateApproval(Event event) {
        jdbc.sql("update events set approved_at = :approvedAt where id = :id")
                .param("approvedAt", event.approvedAt().map(SqlTime::toSql).orElse(null))
                .param("id", event.id().value())
                .update();
    }

    private Optional<Event> findOne(EventId id, String lock) {
        return jdbc.sql(SELECT_EVENTS + "where id = :id" + lock)
                .param("id", id.value())
                .query(this::eventRow)
                .optional()
                .map(row -> row.toEvent(ticketTypes(jdbc.sql("""
                        select event_id, name, price_cents, quantity
                        from ticket_types
                        where event_id = :id
                        order by position
                        """).param("id", id.value())).getOrDefault(row.id(), List.of())));
    }

    /** Ticket types per event ID, in the order the owner entered them. */
    private static Map<UUID, List<TicketType>> ticketTypes(JdbcClient.StatementSpec query) {
        return query
                .query((rs, rowNum) -> Map.entry(
                        rs.getObject("event_id", UUID.class),
                        new TicketType(rs.getString("name"), Money.ofCents(rs.getLong("price_cents")),
                                rs.getInt("quantity"))))
                .list()
                .stream()
                .collect(Collectors.groupingBy(Map.Entry::getKey, LinkedHashMap::new,
                        Collectors.mapping(Map.Entry::getValue, Collectors.toList())));
    }

    private EventRow eventRow(ResultSet rs, int rowNum) throws SQLException {
        return new EventRow(
                rs.getObject("id", UUID.class),
                rs.getObject("business_id", UUID.class),
                rs.getString("name"),
                rs.getObject("starts_at", OffsetDateTime.class).atZoneSameInstant(zone).toLocalDateTime(),
                rs.getString("venue"),
                rs.getBigDecimal("commission_rate"),
                SqlTime.instant(rs, "approved_at"),
                EventKind.fromCode(rs.getString("kind")));
    }

    private record EventRow(UUID id, UUID businessId, String name, LocalDateTime startsAt, String venue,
                            BigDecimal commissionRate, Instant approvedAt, EventKind kind) {

        Event toEvent(List<TicketType> ticketTypes) {
            return Event.restore(new EventId(id), new BusinessId(businessId), name, startsAt, venue, ticketTypes,
                    commissionRate, approvedAt, kind);
        }
    }
}
