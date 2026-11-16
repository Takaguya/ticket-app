package com.ticket.app.backend.booking.infrastructure;

import java.util.Optional;

import com.ticket.app.backend.booking.domain.AttemptId;
import com.ticket.app.backend.booking.domain.BookingAttempts;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.business.domain.StaffId;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Attempts in {@code booking_attempts}. */
@Repository
class JdbcBookingAttempts implements BookingAttempts {

    private final JdbcClient jdbc;

    JdbcBookingAttempts(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<BookingId> bookingOf(AttemptId attempt, Kind kind, StaffId staff) {
        return jdbc.sql("""
                        select booking_id from booking_attempts
                        where attempt_id = :attempt and kind = :kind and staff_id = :staff
                        """)
                .param("attempt", attempt.value())
                .param("kind", code(kind))
                .param("staff", staff.value())
                .query(String.class)
                .optional()
                .map(BookingId::new);
    }

    @Override
    public void record(AttemptId attempt, Kind kind, BookingId booking, StaffId staff) {
        jdbc.sql("""
                        insert into booking_attempts (attempt_id, kind, booking_id, staff_id)
                        values (:attempt, :kind, :booking, :staff)
                        on conflict (attempt_id) do nothing
                        """)
                .param("attempt", attempt.value())
                .param("kind", code(kind))
                .param("booking", booking.value())
                .param("staff", staff.value())
                .update();
    }

    private static String code(Kind kind) {
        return switch (kind) {
            case CHECK_IN -> "checkIn";
            case DOOR_SALE -> "doorSale";
        };
    }
}
