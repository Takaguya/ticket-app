package com.ticket.app.backend.booking.service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.repository.BookingRepository;
import com.ticket.app.backend.booking.model.Payout;
import com.ticket.app.backend.booking.model.PayoutDue;
import com.ticket.app.backend.booking.repository.PayoutRepository;
import com.ticket.app.backend.business.service.BusinessService;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.service.EventService;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.Money;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * What Pin owes each business for its online bookings, and paying it. A payout covers
 * the exact bookings it paid for, so nothing is paid twice or left out.
 */
@Service
public class PayoutService {

    private final BookingRepository bookings;
    private final PayoutRepository payouts;
    private final EventService events;
    private final BusinessService businesses;
    private final Clock clock;

    public PayoutService(BookingRepository bookings, PayoutRepository payouts, EventService events,
                         BusinessService businesses, Clock clock) {
        this.bookings = bookings;
        this.payouts = payouts;
        this.events = events;
        this.businesses = businesses;
        this.clock = clock;
    }

    /** Every business Pin owes money to, the largest amount first. */
    public List<PayoutDue> allDue() {
        Map<EventId, Event> eventsById = events.all().stream()
                .collect(Collectors.toMap(Event::id, Function.identity()));
        Map<BusinessId, List<Booking>> unpaidByBusiness = byBusiness(bookings.findAllUnpaidOnline(), eventsById);
        Map<BusinessId, List<Booking>> refundsByBusiness = byBusiness(bookings.findAllRefundsToRecover(), eventsById);
        return unpaidByBusiness.entrySet().stream()
                .map(entry -> PayoutDue.of(entry.getKey(), entry.getValue(),
                        refundsByBusiness.getOrDefault(entry.getKey(), List.of()),
                        eventId -> eventsById.get(eventId).commissionRate()))
                .filter(PayoutDue::isOwed)
                .sorted(Comparator.comparing(PayoutDue::net).reversed())
                .toList();
    }

    /** What Pin owes the business now. */
    public PayoutDue dueTo(BusinessId business) {
        Map<EventId, BigDecimal> rates = events.eventsOf(business).stream()
                .collect(Collectors.toMap(Event::id, Event::commissionRate));
        return PayoutDue.of(business, bookings.findUnpaidOnline(business), bookings.findRefundsToRecover(business),
                rates::get);
    }

    private static Map<BusinessId, List<Booking>> byBusiness(List<Booking> found, Map<EventId, Event> eventsById) {
        return found.stream()
                .filter(booking -> eventsById.containsKey(booking.eventId()))
                .collect(Collectors.groupingBy(booking -> eventsById.get(booking.eventId()).businessId()));
    }

    /**
     * Records that an admin sent the business everything it is owed. {@code expectedNet}
     * is the amount they saw: if it changed meanwhile the payout is refused. The business
     * is locked, so two admins paying it at once are decided one after the other and the
     * second finds nothing owed.
     */
    @Transactional
    public Payout pay(BusinessId business, Money expectedNet, Payout.PaidBy paidBy) {
        businesses.lock(business);
        PayoutDue due = dueTo(business);
        Payout payout = due.pay(expectedNet, paidBy, clock.instant());
        payouts.add(payout, due.bookings(), due.refundedBookings());
        return payout;
    }

    /** The business's latest payouts, newest first. */
    public List<Payout> paidTo(BusinessId business, int limit) {
        return payouts.findByBusiness(business, limit);
    }

    /** Every payout made from {@code from} until just before {@code until}, newest first. */
    public List<Payout> paidBetween(Instant from, Instant until) {
        return payouts.findPaidBetween(from, until);
    }
}
