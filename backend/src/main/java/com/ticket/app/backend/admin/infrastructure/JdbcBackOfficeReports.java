package com.ticket.app.backend.admin.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import com.ticket.app.backend.admin.domain.BackOfficeReports;
import com.ticket.app.backend.admin.domain.BookingOverview;
import com.ticket.app.backend.admin.domain.EventOverview;
import com.ticket.app.backend.admin.domain.MerchantOverview;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingStatus;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.booking.domain.SalesChannel;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * The back office's lists, each in one query across the modules' tables. Commission
 * is rounded per booking, halves up, as {@code Money.percent} does.
 */
@Repository
class JdbcBackOfficeReports implements BackOfficeReports {

    private final JdbcClient jdbc;
    private final ZoneId zone;

    JdbcBackOfficeReports(JdbcClient jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.zone = clock.getZone();
    }

    @Override
    public List<MerchantOverview> merchants(Instant salesFrom, Instant salesUntil) {
        return jdbc.sql("""
                        select b.id, b.name, b.type, b.status, b.created_at,
                               o.name as owner_name, o.phone as owner_phone,
                               (select count(*) from events e where e.business_id = b.id) as event_count,
                               coalesce(s.online_cents, 0) as online_cents,
                               coalesce(s.commission_cents, 0) as commission_cents
                        from businesses b
                        left join staff_members o
                               on o.business_id = b.id and o.role = 'owner' and o.removed_at is null
                        left join (
                            -- Pin pays for promo codes: the business is paid, and charged commission, on
                            -- the full ticket price (what the buyer paid plus the discount).
                            select e.business_id,
                                   sum(k.total_cents + k.discount_cents) as online_cents,
                                   sum(round((k.total_cents + k.discount_cents) * e.commission_rate / 100))
                                       as commission_cents
                            from bookings k
                            join events e on e.id = k.event_id
                            where k.channel = 'online' and k.status <> 'cancelled'
                              and k.created_at >= :from and k.created_at < :until
                            group by e.business_id
                        ) s on s.business_id = b.id
                        order by case b.status when 'active' then 0 when 'pending' then 1 else 2 end,
                                 online_cents desc, b.name
                        """)
                .param("from", SqlTime.toSql(salesFrom))
                .param("until", SqlTime.toSql(salesUntil))
                .query(JdbcBackOfficeReports::merchant)
                .list();
    }

    @Override
    public List<EventOverview> events() {
        return jdbc.sql("""
                        select e.id, e.name, e.venue, e.starts_at, e.approved_at is not null as approved, e.kind,
                               b.id as business_id, b.name as business_name, b.status as business_status,
                               coalesce((select sum(t.quantity) from ticket_types t where t.event_id = e.id), 0)
                                   as capacity,
                               coalesce((select sum(l.quantity)
                                         from booking_lines l
                                         join bookings k on k.id = l.booking_id
                                         where k.event_id = e.id and k.status <> 'cancelled'), 0) as sold,
                               i.updated_at as image_updated_at
                        from events e
                        join businesses b on b.id = e.business_id
                        left join event_images i on i.event_id = e.id
                        order by e.starts_at
                        """)
                .query(this::event)
                .list();
    }

    @Override
    public BookingOverview.Page bookings(String query, Instant bookedFrom, Instant bookedUntil, int page, int size) {
        String text = query == null ? "" : query.strip().toLowerCase(Locale.ROOT);
        String digits = text.replaceAll("\\D", "");
        String condition = """
                (:text = ''
                 or lower(k.id) like :like escape '\\' or lower(k.buyer_name) like :like escape '\\'
                 or lower(e.name) like :like escape '\\' or lower(b.name) like :like escape '\\'
                 or (length(:digits) >= 3
                     and (substr(k.phone, 2) like :digitsLike or '0' || substr(k.phone, 5) like :digitsLike)))
                """
                + (bookedFrom == null ? "" : "and k.created_at >= :bookedFrom\n")
                + (bookedUntil == null ? "" : "and k.created_at < :bookedUntil\n");
        String from = """
                from bookings k
                join events e on e.id = k.event_id
                join businesses b on b.id = e.business_id
                where
                """;
        Map<String, Object> params = new HashMap<>(Map.of(
                "text", text,
                "like", "%" + escapeLike(text) + "%",
                "digits", digits,
                "digitsLike", "%" + digits + "%"));
        if (bookedFrom != null) {
            params.put("bookedFrom", SqlTime.toSql(bookedFrom));
        }
        if (bookedUntil != null) {
            params.put("bookedUntil", SqlTime.toSql(bookedUntil));
        }

        // The order is total (ID breaks ties), so pages neither overlap nor skip.
        List<BookingOverview> bookings = jdbc.sql("""
                        select k.id, k.buyer_name, e.name as event_name, b.name as business_name,
                               (select coalesce(sum(l.quantity), 0) from booking_lines l where l.booking_id = k.id)
                                   as tickets,
                               k.total_cents, k.payment, k.channel, k.status, k.created_at
                        """ + from + condition + """
                        order by k.created_at desc, k.id
                        limit :limit offset :offset
                        """)
                .params(params)
                .param("limit", size)
                .param("offset", (long) (page - 1) * size)
                .query(JdbcBackOfficeReports::booking)
                .list();
        long total = jdbc.sql("select count(*) " + from + condition)
                .params(params)
                .query(Long.class)
                .single();
        return new BookingOverview.Page(bookings, Math.toIntExact(total), page, size);
    }

    @Override
    public Map<BusinessId, String> businessNames() {
        Map<BusinessId, String> names = new LinkedHashMap<>();
        jdbc.sql("select id, name from businesses order by name")
                .query((rs, rowNum) -> Map.entry(new BusinessId(rs.getObject("id", UUID.class)), rs.getString("name")))
                .list()
                .forEach(entry -> names.put(entry.getKey(), entry.getValue()));
        return names;
    }

    private static MerchantOverview merchant(ResultSet rs, int rowNum) throws SQLException {
        String ownerPhone = rs.getString("owner_phone");
        MerchantOverview.Owner owner = ownerPhone == null
                ? null
                : new MerchantOverview.Owner(rs.getString("owner_name"), new PhoneNumber(ownerPhone));
        return new MerchantOverview(
                new BusinessId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                BusinessType.fromCode(rs.getString("type")),
                BusinessStatus.fromCode(rs.getString("status")),
                owner,
                rs.getInt("event_count"),
                Money.ofCents(rs.getLong("online_cents")),
                Money.ofCents(rs.getLong("commission_cents")),
                SqlTime.instant(rs, "created_at"));
    }

    private EventOverview event(ResultSet rs, int rowNum) throws SQLException {
        Instant imageUpdatedAt = SqlTime.instant(rs, "image_updated_at");
        return new EventOverview(
                new EventId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                rs.getString("venue"),
                rs.getObject("starts_at", OffsetDateTime.class).atZoneSameInstant(zone).toLocalDateTime(),
                new BusinessId(rs.getObject("business_id", UUID.class)),
                rs.getString("business_name"),
                BusinessStatus.fromCode(rs.getString("business_status")),
                rs.getBoolean("approved"),
                rs.getInt("sold"),
                rs.getInt("capacity"),
                EventKind.fromCode(rs.getString("kind")),
                imageUpdatedAt == null ? null : imageUpdatedAt.toEpochMilli());
    }

    private static BookingOverview booking(ResultSet rs, int rowNum) throws SQLException {
        return new BookingOverview(
                new BookingId(rs.getString("id")),
                rs.getString("buyer_name"),
                rs.getString("event_name"),
                rs.getString("business_name"),
                rs.getInt("tickets"),
                Money.ofCents(rs.getLong("total_cents")),
                PaymentMethod.fromCode(rs.getString("payment")),
                SalesChannel.fromCode(rs.getString("channel")),
                BookingStatus.fromCode(rs.getString("status")),
                SqlTime.instant(rs, "created_at"));
    }

    /** {@code 50%_off} matches itself only, not "50" followed by anything. */
    private static String escapeLike(String text) {
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
