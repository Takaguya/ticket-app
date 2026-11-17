package com.ticket.app.backend.booking.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.Payout;
import com.ticket.app.backend.booking.model.PayoutId;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.repository.SqlTime;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Payouts in {@code payouts}; the bookings they cover point to them with
 * {@code payout_id}, the refunds they took back with {@code refund_recovered_by}.
 */
@Repository
class JdbcPayoutRepository implements PayoutRepository {

    private static final String SELECT_PAYOUTS = """
            select id, business_id, gross_cents, commission_cents, refunds_cents, booking_count, paid_at, paid_by,
                   paid_by_name
            from payouts
            """;

    private final JdbcClient jdbc;

    JdbcPayoutRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void add(Payout payout, List<BookingId> bookings, List<BookingId> refundedBookings) {
        jdbc.sql("""
                        insert into payouts (id, business_id, gross_cents, commission_cents, refunds_cents, net_cents,
                                             booking_count, paid_at, paid_by, paid_by_name)
                        values (:id, :businessId, :gross, :commission, :refunds, :net, :bookingCount, :paidAt,
                                :paidBy, :paidByName)
                        """)
                .param("id", payout.id().value())
                .param("businessId", payout.businessId().value())
                .param("gross", payout.gross().cents())
                .param("commission", payout.commission().cents())
                .param("refunds", payout.refunds().cents())
                .param("net", payout.net().cents())
                .param("bookingCount", payout.bookingCount())
                .param("paidAt", SqlTime.toSql(payout.paidAt()))
                .param("paidBy", payout.paidBy().adminId())
                .param("paidByName", payout.paidBy().name())
                .update();

        int marked = jdbc.sql("""
                        update bookings set payout_id = :payoutId
                        where id = any(string_to_array(:ids, ',')) and payout_id is null
                        """)
                .param("payoutId", payout.id().value())
                // Booking IDs are TK and 8 digits, never with commas.
                .param("ids", String.join(",", bookings.stream().map(BookingId::value).toList()))
                .update();
        if (marked != bookings.size()) {
            throw new IllegalStateException("Some bookings of payout " + payout.id() + " were paid out already");
        }

        int recovered = jdbc.sql("""
                        update bookings set refund_recovered_by = :payoutId
                        where id = any(string_to_array(:ids, ',')) and refund_recovered_by is null
                          and status = 'cancelled' and payout_id is not null
                        """)
                .param("payoutId", payout.id().value())
                .param("ids", String.join(",", refundedBookings.stream().map(BookingId::value).toList()))
                .update();
        if (recovered != refundedBookings.size()) {
            throw new IllegalStateException("Some refunds of payout " + payout.id() + " were taken back already");
        }
    }

    @Override
    public List<Payout> findByBusiness(BusinessId businessId, int limit) {
        return jdbc.sql(SELECT_PAYOUTS + "where business_id = :businessId order by paid_at desc limit :limit")
                .param("businessId", businessId.value())
                .param("limit", limit)
                .query(JdbcPayoutRepository::payout)
                .list();
    }

    @Override
    public List<Payout> findPaidBetween(Instant from, Instant until) {
        return jdbc.sql(SELECT_PAYOUTS + "where paid_at >= :from and paid_at < :until order by paid_at desc")
                .param("from", SqlTime.toSql(from))
                .param("until", SqlTime.toSql(until))
                .query(JdbcPayoutRepository::payout)
                .list();
    }

    private static Payout payout(ResultSet rs, int rowNum) throws SQLException {
        return new Payout(
                new PayoutId(rs.getObject("id", UUID.class)),
                new BusinessId(rs.getObject("business_id", UUID.class)),
                Money.ofCents(rs.getLong("gross_cents")),
                Money.ofCents(rs.getLong("commission_cents")),
                Money.ofCents(rs.getLong("refunds_cents")),
                rs.getInt("booking_count"),
                SqlTime.instant(rs, "paid_at"),
                new Payout.PaidBy(rs.getObject("paid_by", UUID.class), rs.getString("paid_by_name")));
    }
}
