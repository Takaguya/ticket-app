package com.ticket.app.backend.demo;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

import com.ticket.app.backend.admin.model.AdminId;
import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.booking.repository.BookingRepository;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.OnlinePurchase;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.booking.model.Payout;
import com.ticket.app.backend.booking.model.PayoutDue;
import com.ticket.app.backend.booking.repository.PayoutRepository;
import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.booking.model.SalesChannel;
import com.ticket.app.backend.booking.model.ShirtSize;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.business.model.BusinessStatus;
import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.buyer.model.Gender;
import com.ticket.app.backend.event.repository.BusTripRepository;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.repository.EventPageRepository;
import com.ticket.app.backend.event.repository.EventRepository;
import com.ticket.app.backend.event.repository.ScreeningRepository;
import com.ticket.app.backend.identity.model.AdminPassword;
import com.ticket.app.backend.identity.repository.AdminPasswordRepository;
import com.ticket.app.backend.identity.model.PasswordHasher;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.model.EmailAddress;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.model.PhoneNumber;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Creates the demo data when {@code pin.demo-data} is true (the dev profile):
 *
 * <ul>
 *   <li>Khmer Runners Club, the business the merchant app's mock also uses: join code
 *       482 913, owner Vannak Sok +855 12 345 678, scanners Dara Keo +855 98 765 432
 *       and Sreyneang Lim +855 87 654 321; a half marathon today, a run in 8 days and
 *       one 3 weeks ago, with bookings. The run 3 weeks ago is paid out.</li>
 *   <li>Buyer Sokha Chan, the user app's demo account (+855 10 222 333), with one booking for
 *       the Kampot run.</li>
 *   <li>Six more businesses for the admin panel ({@link DemoMerchants}): active, waiting
 *       for approval and suspended ones.</li>
 *   <li>Super admin Moniroth Prak, for the admin panel: email {@value #ADMIN_EMAIL},
 *       password {@value #ADMIN_PASSWORD}.</li>
 * </ul>
 *
 * <p>Each event's tickets were booked over the six weeks before it (or before now, for
 * events to come), more of them nearer the event, so the admin panel's dates have
 * sales to show in past weeks and months too.
 *
 * <p>Businesses, staff and the admin are created once; changes made in the apps survive
 * restarts. The events are dated around today: on the first start of a new day the demo
 * businesses' events, bookings and payouts are replaced by fresh sample data, and their
 * statuses set back, so approving and suspending can be tried again.
 */
@Component
@ConditionalOnBooleanProperty("pin.demo-data")
class DemoDataSeeder implements ApplicationRunner {

    static final BusinessId BUSINESS = new BusinessId(uuid("10000000-0000-7000-8000-000000000001"));
    static final StaffId OWNER = new StaffId(uuid("20000000-0000-7000-8000-000000000001"));
    static final StaffId DARA = new StaffId(uuid("20000000-0000-7000-8000-000000000002"));
    static final StaffId SREYNEANG = new StaffId(uuid("20000000-0000-7000-8000-000000000003"));
    static final EventId MARATHON = new EventId(uuid("30000000-0000-7000-8000-000000000001"));
    static final EventId KAMPOT = new EventId(uuid("30000000-0000-7000-8000-000000000002"));
    static final EventId NIGHT_RUN = new EventId(uuid("30000000-0000-7000-8000-000000000003"));
    static final UUID ADMIN = uuid("40000000-0000-7000-8000-000000000001");
    static final BuyerId SOKHA = new BuyerId(uuid("50000000-0000-7000-8000-000000000001"));
    static final String SOKHA_PHONE = "+85510222333";
    static final String SOKHA_NAME = "Sokha Chan";
    static final String SOKHA_EMAIL = "sokha.chan@example.com";
    static final LocalDate SOKHA_BIRTHDAY = LocalDate.of(1996, 4, 12);
    /** Sokha's booking for the Kampot run, with a fixed ID so it is the same after every daily reset. */
    static final BookingId SOKHA_BOOKING = new BookingId("TK50000001");
    static final String ADMIN_NAME = "Moniroth Prak";
    static final String ADMIN_EMAIL = "moniroth@pin.example";
    static final String ADMIN_PASSWORD = "pin-demo-admin";

    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final JdbcClient jdbc;
    private final EventRepository events;
    private final EventPageRepository pages;
    private final BusTripRepository busTrips;
    private final ScreeningRepository screenings;
    private final BookingRepository bookings;
    private final PayoutRepository payouts;
    private final AdminPasswordRepository adminPasswords;
    private final PasswordHasher passwordHasher;
    private final Clock clock;
    private final PinProperties properties;

    DemoDataSeeder(JdbcClient jdbc, EventRepository events, EventPageRepository pages, BusTripRepository busTrips,
                   ScreeningRepository screenings, BookingRepository bookings, PayoutRepository payouts,
                   AdminPasswordRepository adminPasswords, PasswordHasher passwordHasher, Clock clock,
                   PinProperties properties) {
        this.jdbc = jdbc;
        this.events = events;
        this.pages = pages;
        this.busTrips = busTrips;
        this.screenings = screenings;
        this.bookings = bookings;
        this.payouts = payouts;
        this.adminPasswords = adminPasswords;
        this.passwordHasher = passwordHasher;
        this.clock = clock;
        this.properties = properties;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        createBusinessesStaffAndAdmin();

        LocalDate today = LocalDate.now(clock);
        boolean datedToday = events.find(MARATHON)
                .map(event -> event.startsAt().toLocalDate().equals(today))
                .orElse(false);
        if (!datedToday) {
            removeEventsBookingsAndPayouts();
            resetStatuses();
            createKhmerRunnersClubEvents(today);
            createOtherMerchantsEvents(today);
            log.info("Demo data created for {}", today);
        }
        // Not only on the day's first start: a database seeded earlier the same day gets them too.
        ensureBusTrips(today);
        ensureScreenings(today);
        ensurePlaces(today);
        createMissingEventPages();
        createSokhasBookingIfMissing(today);
        log.info("Demo data ready: owner +85512345678, scanner +85598765432, buyer {}, admin {} (password {})",
                SOKHA_PHONE, ADMIN_EMAIL, ADMIN_PASSWORD);
    }

    /** Fixed rows, inserted once. Rows that exist are left as the apps changed them. */
    private void createBusinessesStaffAndAdmin() {
        business(BUSINESS, "Khmer Runners Club", "events", "482913", BusinessStatus.ACTIVE);
        member(OWNER, BUSINESS, "+85512345678", "Vannak Sok", "owner");
        member(DARA, BUSINESS, "+85598765432", "Dara Keo", "scanner");
        member(SREYNEANG, BUSINESS, "+85587654321", "Sreyneang Lim", "scanner");
        for (DemoMerchants.Merchant merchant : DemoMerchants.ALL) {
            business(merchant.id(), merchant.name(), merchant.type().code(), merchant.joinCode(), merchant.status());
            member(merchant.ownerId(), merchant.id(), merchant.ownerPhone(), merchant.ownerName(), "owner");
        }
        jdbc.sql("""
                        insert into buyers (id, phone, name, gender, date_of_birth, email)
                        values (:id, :phone, :name, 'female', :dateOfBirth, :email)
                        on conflict do nothing
                        """)
                .param("id", SOKHA.value())
                .param("phone", SOKHA_PHONE)
                .param("name", SOKHA_NAME)
                .param("dateOfBirth", SOKHA_BIRTHDAY)
                .param("email", SOKHA_EMAIL)
                .update();
        // Gives the email address to a demo admin made before admins had one.
        jdbc.sql("""
                        insert into admins (id, email, name, role) values (:id, :email, :name, 'super_admin')
                        on conflict (id) do update set email = excluded.email where admins.email is null
                        """)
                .param("id", ADMIN)
                .param("email", ADMIN_EMAIL)
                .param("name", ADMIN_NAME)
                .update();
        AdminId admin = new AdminId(ADMIN);
        if (adminPasswords.findAndLock(admin).isEmpty()) {
            adminPasswords.save(AdminPassword.set(admin, ADMIN_PASSWORD, passwordHasher));
        }
    }

    private void business(BusinessId id, String name, String type, String joinCode, BusinessStatus status) {
        jdbc.sql("""
                        insert into businesses (id, name, type, join_code, status)
                        values (:id, :name, :type, :joinCode, :status)
                        on conflict do nothing
                        """)
                .param("id", id.value())
                .param("name", name)
                .param("type", type)
                .param("joinCode", joinCode)
                .param("status", status.code())
                .update();
    }

    private void member(StaffId id, BusinessId business, String phone, String name, String role) {
        jdbc.sql("""
                        insert into staff_members (id, business_id, phone, name, role)
                        values (:id, :businessId, :phone, :name, :role)
                        on conflict do nothing
                        """)
                .param("id", id.value())
                .param("businessId", business.value())
                .param("phone", phone)
                .param("name", name)
                .param("role", role)
                .update();
    }

    private void removeEventsBookingsAndPayouts() {
        for (BusinessId business : demoBusinesses()) {
            jdbc.sql("delete from bookings where event_id in (select id from events where business_id = :id)")
                    .param("id", business.value())
                    .update();
            jdbc.sql("delete from payouts where business_id = :id")
                    .param("id", business.value())
                    .update();
            jdbc.sql("delete from events where business_id = :id")
                    .param("id", business.value())
                    .update();
        }
    }

    private void resetStatuses() {
        setStatus(BUSINESS, BusinessStatus.ACTIVE);
        DemoMerchants.ALL.forEach(merchant -> setStatus(merchant.id(), merchant.status()));
    }

    private void setStatus(BusinessId business, BusinessStatus status) {
        jdbc.sql("update businesses set status = :status where id = :id")
                .param("status", status.code())
                .param("id", business.value())
                .update();
    }

    private void createKhmerRunnersClubEvents(LocalDate today) {
        BigDecimal rate = properties.commissionRate();
        Instant now = clock.instant();
        Event marathon = SampleData.marathon(MARATHON, BUSINESS, today, rate, now);
        Event kampot = SampleData.kampot(KAMPOT, BUSINESS, today, rate, now);
        Event nightRun = SampleData.nightRun(NIGHT_RUN, BUSINESS, today, rate, now);
        List.of(marathon, kampot, nightRun).forEach(events::add);

        var dara = new SampleData.Staff(DARA, "Dara Keo");
        var sreyneang = new SampleData.Staff(SREYNEANG, "Sreyneang Lim");
        ZoneId zone = clock.getZone();

        // Today's event: most guests have arrived since 04:30.
        add(SampleData.bookings(marathon, 64, 20261018, today.atTime(4, 30), true, dara, sreyneang, zone, now));
        // Next week: sold, nobody checked in.
        add(SampleData.bookings(kampot, 110, 77123, null, false, dara, sreyneang, zone, now));
        // Three weeks ago: finished, and Pin has paid for its online sales.
        add(SampleData.bookings(nightRun, 90, 51877, today.minusDays(21).atTime(17, 30), true, dara, sreyneang, zone,
                now));
        PayoutDue owed = PayoutDue.of(BUSINESS, bookings.findByEvent(NIGHT_RUN), event -> rate);
        Payout payout = owed.pay(owed.net(), new Payout.PaidBy(ADMIN, ADMIN_NAME),
                today.minusDays(3).atTime(10, 0).atZone(zone).toInstant());
        payouts.add(payout, owed.bookings(), owed.refundedBookings());
    }

    private void createOtherMerchantsEvents(LocalDate today) {
        BigDecimal rate = properties.commissionRate();
        Instant now = clock.instant();
        ZoneId zone = clock.getZone();
        // Nobody is checked in, so who scanned never comes up.
        var nobody = new SampleData.Staff(DARA, "Dara Keo");
        for (DemoMerchants.Merchant merchant : DemoMerchants.ALL) {
            for (DemoMerchants.DemoEvent demo : merchant.events()) {
                Event event = demo.toEvent(merchant.id(), today, rate, now);
                events.add(event);
                if (demo.bookings() > 0) {
                    add(fitting(event, SampleData.bookings(event, demo.bookings(), demo.seed(), null, false, nobody,
                            nobody, zone, now)));
                }
            }
        }
    }

    /**
     * Giant Ibis's bus trips, with seats taken. A database seeded before bus trips existed has
     * Giant Ibis's old demo events instead: they are replaced by the trips.
     */
    private void ensureBusTrips(LocalDate today) {
        if (busTrips.find(DemoTrips.ALL.getFirst().id()).isPresent()) {
            return;
        }
        jdbc.sql("delete from bookings where event_id in (select id from events where business_id = :id)")
                .param("id", DemoTrips.GIANT_IBIS.value())
                .update();
        jdbc.sql("delete from events where business_id = :id")
                .param("id", DemoTrips.GIANT_IBIS.value())
                .update();

        BigDecimal rate = properties.commissionRate();
        Instant now = clock.instant();
        ZoneId zone = clock.getZone();
        for (DemoTrips.Trip trip : DemoTrips.ALL) {
            Event event = trip.toEvent(DemoTrips.GIANT_IBIS, today, rate, now);
            events.add(event);
            busTrips.add(trip.toBusTrip());
            pages.save(trip.toPage());
            add(DemoTrips.bookings(trip, event, zone, now));
        }
    }

    /**
     * Legend Cinema's screenings, with seats taken. A database seeded before screenings existed has
     * Legend Cinema's old demo events instead: they are replaced by the screenings.
     */
    private void ensureScreenings(LocalDate today) {
        if (screenings.find(DemoScreenings.ALL.getFirst().id()).isPresent()) {
            return;
        }
        jdbc.sql("delete from bookings where event_id in (select id from events where business_id = :id)")
                .param("id", DemoScreenings.LEGEND_CINEMA.value())
                .update();
        jdbc.sql("delete from events where business_id = :id")
                .param("id", DemoScreenings.LEGEND_CINEMA.value())
                .update();

        BigDecimal rate = properties.commissionRate();
        Instant now = clock.instant();
        ZoneId zone = clock.getZone();
        for (DemoScreenings.Show show : DemoScreenings.ALL) {
            Event event = show.toEvent(DemoScreenings.LEGEND_CINEMA, today, rate, now);
            events.add(event);
            screenings.add(show.toScreening());
            pages.save(show.toPage());
            add(DemoScreenings.bookings(show, event, zone, now));
        }
    }

    /**
     * The places of the demo's admission businesses, with visitors booked for the coming days.
     * Garden City's place, made before places existed as a dated concert, becomes a place.
     */
    private void ensurePlaces(LocalDate today) {
        jdbc.sql("update events set kind = 'admission' where id = :id and kind <> 'admission'")
                .param("id", DemoMerchants.GARDEN_CITY_PLACE.value())
                .update();
        if (events.find(DemoPlaces.ALL.getFirst().id()).isPresent()) {
            return;
        }

        BigDecimal rate = properties.commissionRate();
        Instant now = clock.instant();
        ZoneId zone = clock.getZone();
        for (DemoPlaces.Place place : DemoPlaces.ALL) {
            events.add(place.toEvent(today, rate, now));
            pages.save(place.toPage());
            add(DemoPlaces.bookings(place, today, zone, now));
        }
    }

    /** The event pages of the demo events that have none yet; pages an admin or merchant wrote are kept. */
    private void createMissingEventPages() {
        Stream.of(Map.entry(MARATHON, SampleData.marathonPage(MARATHON)),
                        Map.entry(KAMPOT, SampleData.kampotPage(KAMPOT)),
                        Map.entry(NIGHT_RUN, SampleData.nightRunPage(NIGHT_RUN)))
                .forEach(entry -> createPageIfMissing(entry.getKey(), entry.getValue()));
        DemoMerchants.ALL.stream()
                .flatMap(merchant -> merchant.events().stream())
                .forEach(demo -> DemoMerchants.pageOf(demo.id()).ifPresent(page -> createPageIfMissing(demo.id(), page)));
    }

    /** Only for events that exist: the daily reset may not have created this one. */
    private void createPageIfMissing(EventId event, EventPage page) {
        if (events.find(event).isPresent() && pages.find(event).isEmpty()) {
            pages.save(page);
        }
    }

    /**
     * The demo buyer's booking, made a day ago: one 10K ticket for the Kampot run, with
     * herself as the runner and her number as the phone. Not part of the sample bookings,
     * which match the merchant app's mock.
     */
    private void createSokhasBookingIfMissing(LocalDate today) {
        Optional<Event> kampotRun = events.find(KAMPOT);
        if (kampotRun.isEmpty() || bookings.find(SOKHA_BOOKING).isPresent()) {
            return;
        }
        Event kampot = kampotRun.get();
        Instant now = clock.instant();
        int age = Period.between(SOKHA_BIRTHDAY, today).getYears();
        Runner runner = new Runner(SOKHA_NAME, new PhoneNumber(SOKHA_PHONE), new EmailAddress(SOKHA_EMAIL),
                Gender.FEMALE, age, "Cambodian", "Dara Chan", new PhoneNumber("+85512777888"), ShirtSize.M);
        Money price = kampot.ticketType("10K").orElseThrow().price();
        Booking booking = Booking.restore(SOKHA_BOOKING, kampot.id(), SOKHA_NAME, new PhoneNumber(SOKHA_PHONE),
                List.of(new BookingLine("10K", 1)), price, PaymentMethod.ABA_KHQR, SalesChannel.ONLINE,
                BookingStatus.OPEN, List.of(ShirtSize.M.code()), null, null,
                new OnlinePurchase(SOKHA, null, Money.ZERO, runner), now.minus(Duration.ofDays(1)));
        if (!bookings.tryAdd(booking)) {
            log.warn("Demo booking {} was not created: another booking has that ID", SOKHA_BOOKING);
        }
    }

    /**
     * The sample bookings that fit, in order: the generator ignores how many tickets
     * each type has, which matters for small events like a 45-seat bus.
     */
    private static List<Booking> fitting(Event event, List<Booking> sample) {
        Map<String, Integer> left = new HashMap<>();
        event.ticketTypes().forEach(type -> left.put(type.name(), type.quantity()));
        List<Booking> kept = new ArrayList<>();
        for (Booking booking : sample) {
            boolean fits = booking.lines().stream()
                    .allMatch(line -> left.getOrDefault(line.ticketType(), 0) >= line.quantity());
            if (fits) {
                booking.lines().forEach(line -> left.merge(line.ticketType(), -line.quantity(), Integer::sum));
                kept.add(booking);
            }
        }
        return kept;
    }

    private void add(List<Booking> sample) {
        sample.forEach(bookings::tryAdd);
    }

    private static List<BusinessId> demoBusinesses() {
        return Stream.concat(Stream.of(BUSINESS), DemoMerchants.ALL.stream().map(DemoMerchants.Merchant::id)).toList();
    }

    private static UUID uuid(String text) {
        return UUID.fromString(text);
    }
}
