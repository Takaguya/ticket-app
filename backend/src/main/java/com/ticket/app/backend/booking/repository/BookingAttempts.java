package com.ticket.app.backend.booking.repository;

import java.util.Optional;

import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.booking.model.AttemptId;
import com.ticket.app.backend.booking.model.BookingId;

/**
 * Which attempt did each check-in and door sale. A request sent again after a lost
 * answer is then answered with what was done, instead of being refused or done twice.
 */
public interface BookingAttempts {

    enum Kind {
        CHECK_IN,
        DOOR_SALE
    }

    /** The booking this member's attempt changed, if that attempt went through. */
    Optional<BookingId> bookingOf(AttemptId attempt, Kind kind, StaffId staff);

    /** Notes that the attempt went through. Saved in the same transaction as the change. */
    void record(AttemptId attempt, Kind kind, BookingId booking, StaffId staff);
}
