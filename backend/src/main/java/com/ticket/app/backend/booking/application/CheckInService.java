package com.ticket.app.backend.booking.application;

import java.time.Clock;
import java.util.Optional;

import com.ticket.app.backend.booking.domain.AttemptId;
import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingAttempts;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.BookingStatus;
import com.ticket.app.backend.booking.domain.CheckInResult;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.application.EventService;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Deciding a scan. It happens in one transaction with the booking locked, so two
 * scanners can never both admit the same booking. If the server stops before it
 * answers, the transaction either saved the check-in or saved nothing.
 */
@Service
public class CheckInService {

    private final BookingRepository bookings;
    private final BookingAttempts attempts;
    private final EventService events;
    private final SalesRulesRegistry rules;
    private final Clock clock;

    CheckInService(BookingRepository bookings, BookingAttempts attempts, EventService events,
                   SalesRulesRegistry rules, Clock clock) {
        this.bookings = bookings;
        this.attempts = attempts;
        this.events = events;
        this.rules = rules;
        this.clock = clock;
    }

    /**
     * Validates a scanned QR payload or a typed booking ID for one of the staff
     * member's events and, when it is valid, admits the whole booking.
     *
     * @param code    the booking ID; the 8 digits alone are enough
     * @param attempt names this scan. The app sends it again when it retries after a
     *                lost answer: if that same scan already admitted the booking, the
     *                answer is "admitted" again rather than "already checked in".
     */
    @Transactional
    public CheckInResult checkIn(StaffMember staff, EventId eventId, String code, Optional<AttemptId> attempt) {
        Event event = events.eventOf(staff, eventId);

        Optional<BookingId> id = BookingId.parse(code);
        if (id.isEmpty()) {
            return new CheckInResult.NotFound(code == null ? "" : code.strip());
        }
        Optional<Booking> found = bookings.findAndLock(id.get());
        if (found.isEmpty()) {
            return new CheckInResult.NotFound(id.get().value());
        }

        Booking booking = found.get();
        if (!booking.isFor(event.id()) && !sharesGate(staff, event, booking)) {
            return otherEvent(staff, booking);
        }
        event.ensureCheckInOpenOn(events.today());
        // A place's ticket is good on its visit day only. Only an open booking is held to it: a
        // cancelled or already admitted one gets its own answer, and a scan retried after midnight
        // still finds the check-in it made.
        if (booking.status() == BookingStatus.OPEN) {
            booking.ensureVisitDay(events.today());
        }

        CheckInResult result = booking.checkIn(staff, clock.instant());
        if (result instanceof CheckInResult.Admitted) {
            bookings.update(booking);
            attempt.ifPresent(a -> attempts.record(a, BookingAttempts.Kind.CHECK_IN, booking.id(), staff.id()));
            return result;
        }
        if (result instanceof CheckInResult.AlreadyUsed && isRetryOfTheScanThatAdmitted(attempt, staff, booking)) {
            // This scan's answer was lost on the way; it did admit them.
            return new CheckInResult.Admitted(booking);
        }
        return result;
    }

    /**
     * Whether a scan at {@code scanned} may admit this ticket although it is for another event:
     * the scanned event's sales rules decide (the places of one business share a gate).
     */
    private boolean sharesGate(StaffMember staff, Event scanned, Booking booking) {
        return events.find(booking.eventId())
                .map(ticketEvent -> rules.forKind(scanned.kind()).sharesGate(staff, scanned, ticketEvent))
                .orElse(false);
    }

    private boolean isRetryOfTheScanThatAdmitted(Optional<AttemptId> attempt, StaffMember staff, Booking booking) {
        return attempt
                .flatMap(a -> attempts.bookingOf(a, BookingAttempts.Kind.CHECK_IN, staff.id()))
                .filter(booking.id()::equals)
                .isPresent();
    }

    private CheckInResult otherEvent(StaffMember staff, Booking booking) {
        Optional<Event> real = events.find(booking.eventId());
        String eventName = real.map(Event::name).orElse("another event");
        boolean ours = real.map(event -> event.belongsTo(staff.businessId())).orElse(false);
        return ours
                ? new CheckInResult.OtherEvent(booking.id(), eventName, booking.buyerName(), booking.summary())
                : new CheckInResult.OtherEvent(booking.id(), eventName, null, null);
    }
}
