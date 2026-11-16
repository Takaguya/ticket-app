package com.ticket.app.backend.booking.application;

import java.time.Clock;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.BookingStatus;
import com.ticket.app.backend.booking.domain.CancelReason;
import com.ticket.app.backend.business.application.BusinessService;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.application.EventService;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The owner cancelling a booking from the merchant app. Pin refunds a booking bought
 * online ({@link Booking#refund()}); if it had already paid the business for it, the
 * next payout takes the business's share back ({@code PayoutDue}).
 *
 * <p>The business is locked first, as payouts lock it, so a payout and a cancellation
 * are decided one after the other: a payout never covers a booking that is being
 * cancelled. Then the booking is locked, as check-in locks it, so a guest is never
 * admitted on a booking that is being cancelled.
 */
@Service
public class CancellationService {

    private final BookingRepository bookings;
    private final EventService events;
    private final BusinessService businesses;
    private final Clock clock;

    public CancellationService(BookingRepository bookings, EventService events, BusinessService businesses,
                               Clock clock) {
        this.bookings = bookings;
        this.events = events;
        this.businesses = businesses;
        this.clock = clock;
    }

    /**
     * Cancels one of the owner's business's bookings, for a reason the buyer is shown.
     * A booking already cancelled is returned as it is. Refused when it is checked in,
     * or its event has ended.
     */
    @Transactional
    public Booking cancel(StaffMember owner, BookingId id, CancelReason reason) {
        businesses.lock(owner.businessId());
        Booking booking = bookings.findAndLock(id).orElseThrow(CancellationService::notFound);
        Event event = events.find(booking.eventId())
                .filter(found -> found.belongsTo(owner.businessId()))
                .orElseThrow(CancellationService::notFound);

        if (booking.status() == BookingStatus.CANCELLED) {
            return booking;
        }
        event.ensureNotEndedOn(events.today());
        if (booking.isVisitOver(events.today())) {
            // A place never ends; its booking does, when its visit day has passed.
            throw BusinessRuleException.conflict("The event has ended.");
        }
        if (booking.cancel(owner, reason, clock.instant())) {
            bookings.update(booking);
        }
        return booking;
    }

    private static NotFoundException notFound() {
        return new NotFoundException("This booking does not exist.");
    }
}
