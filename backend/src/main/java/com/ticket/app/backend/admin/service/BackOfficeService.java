package com.ticket.app.backend.admin.service;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.admin.repository.BackOfficeReports;
import com.ticket.app.backend.admin.model.BookingOverview;
import com.ticket.app.backend.admin.model.EventOverview;
import com.ticket.app.backend.admin.model.MerchantOverview;
import com.ticket.app.backend.booking.service.PayoutService;
import com.ticket.app.backend.booking.model.Payout;
import com.ticket.app.backend.booking.model.PayoutDue;
import com.ticket.app.backend.business.service.BusinessService;
import com.ticket.app.backend.business.model.Business;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.service.EventService;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.Money;
import org.springframework.stereotype.Service;

/**
 * What the admin panel shows and does. Sales, commission and payouts made are counted
 * for a period of days the admin chooses; by default this month in Pin's time zone,
 * from the 1st to today.
 */
@Service
public class BackOfficeService {

    /** Most bookings one page of a search holds. */
    public static final int MAX_PAGE_SIZE = 100;

    private final BackOfficeReports reports;
    private final BusinessService businesses;
    private final EventService events;
    private final PayoutService payouts;
    private final Clock clock;
    private final PinProperties properties;

    public BackOfficeService(BackOfficeReports reports, BusinessService businesses, EventService events,
                             PayoutService payouts, Clock clock, PinProperties properties) {
        this.reports = reports;
        this.businesses = businesses;
        this.events = events;
        this.payouts = payouts;
        this.clock = clock;
        this.properties = properties;
    }

    /** The days figures are counted for, both included, in Pin's time zone. */
    public record Period(LocalDate from, LocalDate to) {

        public Period {
            Objects.requireNonNull(from, "from");
            Objects.requireNonNull(to, "to");
            if (from.isAfter(to)) {
                throw BusinessRuleException.invalid("The start date must be on or before the end date.");
            }
        }
    }

    /** A business Pin owes money to, by name. */
    public record Owed(String businessName, PayoutDue due) {
    }

    /** A payout made in the period, with the name of the business paid. */
    public record Paid(String businessName, Payout payout) {
    }

    public record Payouts(List<Owed> owed, List<Paid> paid) {
    }

    /** The default period: this month up to today. */
    public Period period() {
        LocalDate today = today();
        return new Period(today.withDayOfMonth(1), today);
    }

    /**
     * The period the panel asks for, with dates written like {@code 2026-11-01}. A date
     * left out is the default's: the 1st of this month, or today.
     */
    public Period period(String from, String to) {
        Period standard = period();
        return new Period(isBlank(from) ? standard.from() : date(from), isBlank(to) ? standard.to() : date(to));
    }

    public LocalDate today() {
        return LocalDate.now(clock);
    }

    /** Percent Pin keeps of online sales, for newly published events. */
    public BigDecimal commissionRate() {
        return properties.commissionRate();
    }

    /** Every business, with its online sales in the period. */
    public List<MerchantOverview> merchants(Period period) {
        return reports.merchants(start(period), end(period));
    }

    /** Events still to come, soonest first, then those that have ended, latest first. */
    public List<EventOverview> events() {
        LocalDate today = today();
        Comparator<EventOverview> soonestFirst = Comparator.comparing(EventOverview::startsAt);
        Comparator<EventOverview> order = Comparator
                .comparing((EventOverview event) -> event.statusOn(today) == EventOverview.Status.ENDED)
                .thenComparing((a, b) -> a.statusOn(today) == EventOverview.Status.ENDED
                        ? soonestFirst.compare(b, a)
                        : soonestFirst.compare(a, b));
        return reports.events().stream().sorted(order).toList();
    }

    /**
     * One page of the bookings matching the search and made in the period (any time
     * when empty), newest first. A page past the last one is empty.
     */
    public BookingOverview.Page bookings(String query, Optional<Period> period, int page, int size) {
        return reports.bookings(query, period.map(this::start).orElse(null), period.map(this::end).orElse(null),
                Math.max(1, page), Math.clamp(size, 1, MAX_PAGE_SIZE));
    }

    public Business approveMerchant(BusinessId id) {
        return businesses.approve(id);
    }

    public Business suspendMerchant(BusinessId id) {
        return businesses.suspend(id);
    }

    public Business reinstateMerchant(BusinessId id) {
        return businesses.reinstate(id);
    }

    public Event approveEvent(EventId id) {
        return events.approve(id);
    }

    /** Who Pin owes money to now, the largest amount first, and the payouts made in the period. */
    public Payouts payouts(Period period) {
        Map<BusinessId, String> names = reports.businessNames();
        List<Owed> owed = payouts.allDue().stream()
                .map(due -> new Owed(names.getOrDefault(due.businessId(), "Unknown business"), due))
                .toList();
        List<Paid> paid = payouts.paidBetween(start(period), end(period)).stream()
                .map(payout -> new Paid(names.getOrDefault(payout.businessId(), "Unknown business"), payout))
                .toList();
        return new Payouts(owed, paid);
    }

    /**
     * Records that {@code admin} sent the business what it is owed. Refused if the
     * amount owed is no longer {@code expectedNet}.
     */
    public Paid pay(Admin admin, BusinessId business, Money expectedNet) {
        Payout payout = payouts.pay(business, expectedNet, admin.asPayer());
        String name = businesses.find(business).map(Business::name).orElse("Unknown business");
        return new Paid(name, payout);
    }

    /** The first moment of the period. */
    private Instant start(Period period) {
        return period.from().atStartOfDay(clock.getZone()).toInstant();
    }

    /** The moment just after the period: midnight after its last day. */
    private Instant end(Period period) {
        return period.to().plusDays(1).atStartOfDay(clock.getZone()).toInstant();
    }

    private static boolean isBlank(String text) {
        return text == null || text.isBlank();
    }

    private static LocalDate date(String text) {
        try {
            return LocalDate.parse(text.strip());
        } catch (DateTimeParseException e) {
            throw BusinessRuleException.invalid("Write dates like 2026-11-14.");
        }
    }
}
