package com.ticket.app.backend.booking.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.SeatBooking;

/** Where bookings and their lines are kept. */
public interface BookingRepository {

    /**
     * The booking, held until the transaction ends. Check-in locks it, so two
     * scanners can never both admit the same booking.
     */
    Optional<Booking> findAndLock(BookingId id);

    Optional<Booking> find(BookingId id);

    List<Booking> findByEvent(EventId eventId);

    /** A place's bookings for one visit day: what that day's limits are counted from. */
    List<Booking> findByEventVisiting(EventId eventId, LocalDate visitDate);

    /** Every booking for any of the business's events. */
    List<Booking> findByBusiness(BusinessId businessId);

    /** The bookings a buyer made in the Pin app, for any event. */
    List<Booking> findByBuyer(BuyerId buyerId);

    /** The business's online bookings, not cancelled, that no payout covers yet. */
    List<Booking> findUnpaidOnline(BusinessId businessId);

    /** Every business's online bookings, not cancelled, that no payout covers yet. */
    List<Booking> findAllUnpaidOnline();

    /**
     * The business's paid-out bookings that were cancelled since, whose refunds no payout
     * has taken back yet.
     */
    List<Booking> findRefundsToRecover(BusinessId businessId);

    /** {@link #findRefundsToRecover} for every business. */
    List<Booking> findAllRefundsToRecover();

    /**
     * The seats of a bus trip that live bookings hold: those of cancelled bookings are free
     * again. The caller holds the event while it books seats.
     */
    List<SeatBooking> findHeldSeats(EventId eventId);

    /**
     * Saves a new booking, and the seats it holds, unless another booking already has its ID.
     *
     * @return whether it was saved
     * @throws IllegalStateException if a seat is held by another live booking; the caller
     *                               holds the event and checks first, so this never happens
     */
    boolean tryAdd(Booking booking);

    /** Saves a changed status, check-in and cancellation; a cancelled booking frees its seats. */
    void update(Booking booking);
}
