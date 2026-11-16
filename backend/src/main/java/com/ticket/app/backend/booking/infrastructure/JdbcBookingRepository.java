package com.ticket.app.backend.booking.infrastructure;

import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.BookingStatus;
import com.ticket.app.backend.booking.domain.CancelReason;
import com.ticket.app.backend.booking.domain.Cancellation;
import com.ticket.app.backend.booking.domain.CheckIn;
import com.ticket.app.backend.booking.domain.OnlinePurchase;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.booking.domain.Runner;
import com.ticket.app.backend.booking.domain.SalesChannel;
import com.ticket.app.backend.booking.domain.SeatBooking;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.buyer.domain.BuyerId;
import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import com.ticket.app.backend.shared.infrastructure.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Bookings in {@code bookings}, their tickets in {@code booking_lines} and the runner
 * of a race in {@code booking_runners}.
 */
@Repository
class JdbcBookingRepository implements BookingRepository {

    private static final String SELECT_BOOKINGS = """
            select id, event_id, buyer_name, phone, total_cents, payment, channel, status, tshirt_sizes,
                   checked_in_at, checked_in_by, checked_in_by_name, cancelled_at, cancelled_by, cancelled_by_name,
                   cancel_reason, buyer_id, promo_code, discount_cents, visit_date, created_at
            from bookings
            """;

    /** Online bookings, not cancelled, that no payout covers yet (index bookings_unpaid). */
    private static final String UNPAID_ONLINE =
            "b.payout_id is null and b.channel = 'online' and b.status <> 'cancelled'";

    /** Paid-out bookings cancelled since, whose refunds no payout took back (index bookings_refunds_to_recover). */
    private static final String REFUNDS_TO_RECOVER =
            "b.status = 'cancelled' and b.payout_id is not null and b.refund_recovered_by is null";

    /**
     * Seats front to back, then left to right. A hall's seats (F5) by row letter, then number; a
     * coach's (3A) by row number, then column. So 2A comes before 10A and F5 before F10.
     */
    private static final String SEAT_ORDER = """
            coalesce(substring(seat_id from '^[A-J]'), ''), regexp_replace(seat_id, '[^0-9]', '', 'g')::int, seat_id""";

    private final JdbcClient jdbc;

    JdbcBookingRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<Booking> findAndLock(BookingId id) {
        return findOne(id, " for update");
    }

    @Override
    public Optional<Booking> find(BookingId id) {
        return findOne(id, "");
    }

    private Optional<Booking> findOne(BookingId id, String lock) {
        return jdbc.sql(SELECT_BOOKINGS + "where id = :id" + lock)
                .param("id", id.value())
                .query(JdbcBookingRepository::bookingRow)
                .optional()
                .map(row -> row.toBooking(lines("""
                        select booking_id, ticket_type, quantity
                        from booking_lines
                        where booking_id = :id
                        order by position
                        """, id.value()),
                        runnersByBooking("""
                                select booking_id, %s
                                from booking_runners
                                where booking_id = :id
                                """.formatted(RunnerColumns.SELECT), id.value()).get(id.value()),
                        seatsByBooking("""
                                select booking_id, seat_id, passenger_gender
                                from booking_seats
                                where booking_id = :id
                                order by %s
                                """.formatted(SEAT_ORDER), id.value()).getOrDefault(id.value(), List.of())));
    }

    @Override
    public List<SeatBooking> findHeldSeats(EventId eventId) {
        return jdbc.sql("select seat_id, passenger_gender from booking_seats where event_id = :id and held")
                .param("id", eventId.value())
                .query((rs, rowNum) -> seat(rs))
                .list();
    }

    @Override
    public List<Booking> findByEvent(EventId eventId) {
        return findWhere("b.event_id = :id", eventId.value());
    }

    @Override
    public List<Booking> findByEventVisiting(EventId eventId, LocalDate visitDate) {
        return findWhere("b.event_id = :id and b.visit_date = :visit", eventId.value(), visitDate);
    }

    @Override
    public List<Booking> findByBusiness(BusinessId businessId) {
        return findWhere("b.event_id in (select id from events where business_id = :id)", businessId.value());
    }

    @Override
    public List<Booking> findByBuyer(BuyerId buyerId) {
        return findWhere("b.buyer_id = :id", buyerId.value());
    }

    @Override
    public List<Booking> findUnpaidOnline(BusinessId businessId) {
        return findWhere(UNPAID_ONLINE + " and b.event_id in (select id from events where business_id = :id)",
                businessId.value());
    }

    @Override
    public List<Booking> findAllUnpaidOnline() {
        // :id is not used; findWhere always passes one.
        return findWhere(UNPAID_ONLINE, null);
    }

    @Override
    public List<Booking> findRefundsToRecover(BusinessId businessId) {
        return findWhere(REFUNDS_TO_RECOVER + " and b.event_id in (select id from events where business_id = :id)",
                businessId.value());
    }

    @Override
    public List<Booking> findAllRefundsToRecover() {
        return findWhere(REFUNDS_TO_RECOVER, null);
    }

    /**
     * Bookings matching a condition on {@code b}, the bookings table, with their lines,
     * runners and seats: four queries in all.
     */
    private List<Booking> findWhere(String condition, Object id) {
        return findWhere(condition, id, null);
    }

    /** As above, for a condition that also uses {@code :visit}, a visit day. */
    private List<Booking> findWhere(String condition, Object id, LocalDate visit) {
        List<BookingRow> rows = jdbc.sql(SELECT_BOOKINGS + " b where " + condition)
                .param("id", id)
                .param("visit", visit)
                .query(JdbcBookingRepository::bookingRow)
                .list();
        Map<String, List<BookingLine>> lines = linesByBooking("""
                select l.booking_id, l.ticket_type, l.quantity
                from booking_lines l
                join bookings b on b.id = l.booking_id
                where %s
                order by l.booking_id, l.position
                """.formatted(condition), id, visit);
        Map<String, Runner> runners = runnersByBooking("""
                select booking_id, %s
                from booking_runners
                where booking_id in (select b.id from bookings b where %s)
                """.formatted(RunnerColumns.SELECT, condition), id, visit);
        Map<String, List<SeatBooking>> seats = seatsByBooking("""
                select booking_id, seat_id, passenger_gender
                from booking_seats
                where booking_id in (select b.id from bookings b where %s)
                order by booking_id, %s
                """.formatted(condition, SEAT_ORDER), id, visit);
        return rows.stream()
                .map(row -> row.toBooking(lines.getOrDefault(row.id(), List.of()), runners.get(row.id()),
                        seats.getOrDefault(row.id(), List.of())))
                .toList();
    }

    @Override
    public boolean tryAdd(Booking booking) {
        CheckIn checkIn = booking.checkIn();
        Cancellation cancellation = booking.cancellation();
        OnlinePurchase purchase = booking.purchase();
        int inserted = jdbc.sql("""
                        insert into bookings (id, event_id, buyer_name, phone, total_cents, payment, channel, status,
                                              tshirt_sizes, checked_in_at, checked_in_by, checked_in_by_name,
                                              cancelled_at, cancelled_by, cancelled_by_name, cancel_reason,
                                              buyer_id, promo_code, discount_cents, visit_date, created_at)
                        values (:id, :eventId, :buyerName, :phone, :totalCents, :payment, :channel, :status,
                                string_to_array(:tshirtSizes, ','), :checkedInAt, :checkedInBy, :checkedInByName,
                                :cancelledAt, :cancelledBy, :cancelledByName, :cancelReason,
                                :buyerId, :promoCode, :discountCents, :visitDate, :createdAt)
                        on conflict (id) do nothing
                        """)
                .param("id", booking.id().value())
                .param("eventId", booking.eventId().value())
                .param("buyerName", booking.buyerName())
                .param("phone", booking.phone().value())
                .param("totalCents", booking.total().cents())
                .param("payment", booking.payment().code())
                .param("channel", booking.channel().code())
                .param("status", booking.status().code())
                // Sizes are short codes like M or XL, never with commas.
                .param("tshirtSizes", String.join(",", booking.tshirtSizes()))
                .param("checkedInAt", checkIn == null ? null : SqlTime.toSql(checkIn.at()))
                .param("checkedInBy", checkIn == null ? null : checkIn.staffId().value())
                .param("checkedInByName", checkIn == null ? null : checkIn.staffName())
                .param("cancelledAt", cancellation == null ? null : SqlTime.toSql(cancellation.at()))
                .param("cancelledBy", cancellation == null ? null : cancellation.staffId().value())
                .param("cancelledByName", cancellation == null ? null : cancellation.staffName())
                .param("cancelReason", cancellation == null ? null : cancellation.reason().code())
                .param("buyerId", purchase == null ? null : purchase.buyer().value())
                .param("promoCode", purchase == null ? null : purchase.promoCode())
                .param("discountCents", booking.discount().cents())
                .param("visitDate", booking.visitDate())
                .param("createdAt", SqlTime.toSql(booking.createdAt()))
                .update();
        if (inserted == 0) {
            return false;
        }
        if (purchase != null && purchase.runner() != null) {
            RunnerColumns.bind(jdbc.sql("""
                            insert into booking_runners (booking_id, name, phone, email, gender, age, nationality,
                                                         emergency_name, emergency_phone, shirt_size)
                            values (:bookingId, :name, :phone, :email, :gender, :age, :nationality,
                                    :emergencyName, :emergencyPhone, :shirtSize)
                            """), purchase.runner())
                    .param("bookingId", booking.id().value())
                    .update();
        }

        List<BookingLine> lines = booking.lines();
        for (int position = 0; position < lines.size(); position++) {
            jdbc.sql("""
                            insert into booking_lines (booking_id, position, ticket_type, quantity)
                            values (:bookingId, :position, :ticketType, :quantity)
                            """)
                    .param("bookingId", booking.id().value())
                    .param("position", position)
                    .param("ticketType", lines.get(position).ticketType())
                    .param("quantity", lines.get(position).quantity())
                    .update();
        }

        for (SeatBooking seat : booking.seats()) {
            jdbc.sql("""
                            insert into booking_seats (booking_id, event_id, seat_id, passenger_gender, held)
                            values (:bookingId, :eventId, :seatId, :gender, :held)
                            """)
                    .param("bookingId", booking.id().value())
                    .param("eventId", booking.eventId().value())
                    .param("seatId", seat.seatId())
                    .param("gender", seat.passengerGender() == null ? null : seat.passengerGender().code())
                    .param("held", booking.status() != BookingStatus.CANCELLED)
                    .update();
        }
        return true;
    }

    @Override
    public void update(Booking booking) {
        CheckIn checkIn = booking.checkIn();
        Cancellation cancellation = booking.cancellation();
        jdbc.sql("""
                        update bookings
                        set status = :status, checked_in_at = :checkedInAt,
                            checked_in_by = :checkedInBy, checked_in_by_name = :checkedInByName,
                            cancelled_at = :cancelledAt, cancelled_by = :cancelledBy,
                            cancelled_by_name = :cancelledByName, cancel_reason = :cancelReason
                        where id = :id
                        """)
                .param("status", booking.status().code())
                .param("checkedInAt", checkIn == null ? null : SqlTime.toSql(checkIn.at()))
                .param("checkedInBy", checkIn == null ? null : checkIn.staffId().value())
                .param("checkedInByName", checkIn == null ? null : checkIn.staffName())
                .param("cancelledAt", cancellation == null ? null : SqlTime.toSql(cancellation.at()))
                .param("cancelledBy", cancellation == null ? null : cancellation.staffId().value())
                .param("cancelledByName", cancellation == null ? null : cancellation.staffName())
                .param("cancelReason", cancellation == null ? null : cancellation.reason().code())
                .param("id", booking.id().value())
                .update();
        if (booking.status() == BookingStatus.CANCELLED) {
            // The seats of a cancelled booking are free for another buyer.
            jdbc.sql("update booking_seats set held = false where booking_id = :id")
                    .param("id", booking.id().value())
                    .update();
        }
    }

    /** Seats per booking ID, in seat order; bookings that hold none are left out. */
    private Map<String, List<SeatBooking>> seatsByBooking(String sql, Object id) {
        return seatsByBooking(sql, id, null);
    }

    private Map<String, List<SeatBooking>> seatsByBooking(String sql, Object id, LocalDate visit) {
        return jdbc.sql(sql)
                .param("id", id)
                .param("visit", visit)
                .query((rs, rowNum) -> Map.entry(rs.getString("booking_id"), seat(rs)))
                .list()
                .stream()
                .collect(Collectors.groupingBy(Map.Entry::getKey, LinkedHashMap::new,
                        Collectors.mapping(Map.Entry::getValue, Collectors.toList())));
    }

    private static SeatBooking seat(ResultSet rs) throws SQLException {
        String gender = rs.getString("passenger_gender");
        return new SeatBooking(rs.getString("seat_id"), gender == null ? null : Gender.fromCode(gender));
    }

    private List<BookingLine> lines(String sql, String bookingId) {
        return linesByBooking(sql, bookingId).getOrDefault(bookingId, List.of());
    }

    /** The runner of each race booking, by booking ID; bookings without one are left out. */
    private Map<String, Runner> runnersByBooking(String sql, Object id) {
        return runnersByBooking(sql, id, null);
    }

    private Map<String, Runner> runnersByBooking(String sql, Object id, LocalDate visit) {
        return jdbc.sql(sql)
                .param("id", id)
                .param("visit", visit)
                .query((rs, rowNum) -> Map.entry(rs.getString("booking_id"), RunnerColumns.read(rs)))
                .list()
                .stream()
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
    }

    /** Lines per booking ID, in the order they were bought. */
    private Map<String, List<BookingLine>> linesByBooking(String sql, Object id) {
        return linesByBooking(sql, id, null);
    }

    private Map<String, List<BookingLine>> linesByBooking(String sql, Object id, LocalDate visit) {
        return jdbc.sql(sql)
                .param("id", id)
                .param("visit", visit)
                .query((rs, rowNum) -> Map.entry(
                        rs.getString("booking_id"),
                        new BookingLine(rs.getString("ticket_type"), rs.getInt("quantity"))))
                .list()
                .stream()
                .collect(Collectors.groupingBy(Map.Entry::getKey, LinkedHashMap::new,
                        Collectors.mapping(Map.Entry::getValue, Collectors.toList())));
    }

    private static BookingRow bookingRow(ResultSet rs, int rowNum) throws SQLException {
        Instant checkedInAt = SqlTime.instant(rs, "checked_in_at");
        CheckIn checkIn = checkedInAt == null ? null : new CheckIn(
                checkedInAt,
                new StaffId(rs.getObject("checked_in_by", UUID.class)),
                rs.getString("checked_in_by_name"));
        Instant cancelledAt = SqlTime.instant(rs, "cancelled_at");
        Cancellation cancellation = cancelledAt == null ? null : new Cancellation(
                cancelledAt,
                new StaffId(rs.getObject("cancelled_by", UUID.class)),
                rs.getString("cancelled_by_name"),
                CancelReason.fromCode(rs.getString("cancel_reason")));
        Array sizes = rs.getArray("tshirt_sizes");
        return new BookingRow(
                rs.getString("id"),
                new EventId(rs.getObject("event_id", UUID.class)),
                rs.getString("buyer_name"),
                new PhoneNumber(rs.getString("phone")),
                Money.ofCents(rs.getLong("total_cents")),
                PaymentMethod.fromCode(rs.getString("payment")),
                SalesChannel.fromCode(rs.getString("channel")),
                BookingStatus.fromCode(rs.getString("status")),
                sizes == null ? List.of() : List.of((String[]) sizes.getArray()),
                checkIn,
                cancellation,
                rs.getObject("buyer_id", UUID.class),
                rs.getString("promo_code"),
                Money.ofCents(rs.getLong("discount_cents")),
                rs.getObject("visit_date", LocalDate.class),
                SqlTime.instant(rs, "created_at"));
    }

    /**
     * @param buyerId set exactly for bookings bought in the Pin app
     */
    private record BookingRow(String id, EventId eventId, String buyerName, PhoneNumber phone, Money total,
                              PaymentMethod payment, SalesChannel channel, BookingStatus status,
                              List<String> tshirtSizes, CheckIn checkIn, Cancellation cancellation, UUID buyerId,
                              String promoCode, Money discount, LocalDate visitDate, Instant createdAt) {

        /**
         * @param runner the race booking's runner; null when it has none
         * @param seats  the bus trip's seats; empty for any other event
         */
        Booking toBooking(List<BookingLine> lines, Runner runner, List<SeatBooking> seats) {
            OnlinePurchase purchase = buyerId == null ? null
                    : new OnlinePurchase(new BuyerId(buyerId), promoCode, discount, runner);
            return Booking.restore(new BookingId(id), eventId, buyerName, phone, lines, total, payment, channel,
                    status, tshirtSizes, checkIn, cancellation, purchase, seats, visitDate, createdAt);
        }
    }
}
