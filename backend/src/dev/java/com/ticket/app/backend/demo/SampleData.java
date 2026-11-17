package com.ticket.app.backend.demo;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.CheckIn;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.booking.model.SalesChannel;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * The demo events and bookings, the same as the merchant app's mock backend
 * ({@code lib/mock_backend/mock_merchant_backend.dart}): the same generator and
 * seeds give the same buyers, booking IDs and check-ins.
 */
final class SampleData {

    record Staff(StaffId id, String name) {
    }

    private static final String[] FIRST_NAMES = {
            "Sokha", "Dara", "Bopha", "Chanthy", "Vichea", "Sreymom", "Rithy", "Kunthea",
            "Piseth", "Sophea", "Makara", "Leakhena", "Visal", "Chenda", "Narith", "Malis",
    };
    private static final String[] LAST_NAMES = {
            "Chan", "Keo", "Sok", "Meas", "Lim", "Heng", "Chea", "Ouk", "Pich", "Ros", "Seng", "Tep",
    };
    private static final String[] SIZES = {"XS", "S", "M", "M", "L", "L", "XL"};

    /** Six weeks: how long before sales closed the demo's tickets were bought. */
    static final int SALES_DAYS = 42;

    /** 08:00 to 22:00. */
    private static final int DAYTIME_MINUTES = 14 * 60;

    private SampleData() {
    }

    /** Today, 05:30: the live event. All three are approved, at {@code approvedAt}. */
    static Event marathon(EventId id, BusinessId business, LocalDate today, BigDecimal commissionRate,
                          Instant approvedAt) {
        return Event.restore(id, business, "Phnom Penh Half Marathon 2026", today.atTime(5, 30),
                "Riverside, Sisowath Quay", List.of(
                        type("5K Fun run", 1200, 100),
                        type("10K", 1800, 80),
                        type("21K Half marathon", 2500, 40)),
                commissionRate, approvedAt, EventKind.MARATHON);
    }

    /** In 8 days. */
    static Event kampot(EventId id, BusinessId business, LocalDate today, BigDecimal commissionRate,
                        Instant approvedAt) {
        return Event.restore(id, business, "Kampot River Run 2026", today.plusDays(8).atTime(6, 0),
                "Old Bridge, Kampot", List.of(
                        type("5K", 1000, 150),
                        type("10K", 1500, 150),
                        type("21K Half marathon", 2200, 150)),
                commissionRate, approvedAt, EventKind.MARATHON);
    }

    /** Three weeks ago. */
    static Event nightRun(EventId id, BusinessId business, LocalDate today, BigDecimal commissionRate,
                          Instant approvedAt) {
        return Event.restore(id, business, "Riverside Night Run 2026", today.minusDays(21).atTime(18, 30),
                "Riverside, Sisowath Quay", List.of(
                        type("3K Family run", 800, 120),
                        type("5K", 1200, 120),
                        type("10K", 1800, 120)),
                commissionRate, approvedAt, EventKind.MARATHON);
    }

    /** What the user app's event page shows for the half marathon, as the app's own mock describes it. */
    static EventPage marathonPage(EventId id) {
        return new EventPage(id, "Start & finish at the Royal Palace",
                "The annual riverside race. Race kit pickup two days before at Aeon Mall. Timing chip, "
                        + "finisher medal and T-shirt included with every distance.",
                "Non-refundable · transferable until a week before",
                List.of("Start 06:30", "Start 06:00", "Start 05:30"));
    }

    /** The user app's event page for the Kampot run. */
    static EventPage kampotPage(EventId id) {
        return new EventPage(id, "Start & finish at the Old Bridge, Kampot",
                "A run along the Kampot River. Race kit pickup the day before at the Old Market. Timing "
                        + "chip, finisher medal and T-shirt included with every distance.",
                "Non-refundable · transferable until a week before",
                List.of("Start 06:30", "Start 06:15", "Start 06:00"));
    }

    /** The user app's event page for the night run. */
    static EventPage nightRunPage(EventId id) {
        return new EventPage(id, "Start & finish at the Royal Palace",
                "An evening run along the river, lit up after dark. Timing chip and T-shirt included "
                        + "with every distance.",
                "Non-refundable · transferable until a week before",
                List.of("Start 18:45", "Start 18:30", "Start 18:15"));
    }

    /**
     * {@code count} online bookings for the event, which needs at least 3 ticket types;
     * the same seed always gives the same list. When {@code firstCheckIn} is set, about
     * two thirds are checked in, a little later each time, by one of the two scanners.
     * They were booked over the weeks before the event ({@link #bookedAt}).
     */
    static List<Booking> bookings(Event event, int count, long seed, LocalDateTime firstCheckIn, boolean withSizes,
                                  Staff dara, Staff sreyneang, ZoneId zone, Instant now) {
        Xorshift random = new Xorshift(seed);
        List<TicketType> types = event.ticketTypes();
        Set<String> ids = new HashSet<>();
        List<Booking> bookings = new ArrayList<>();
        int minutes = 2;

        for (int i = 0; i < count; i++) {
            double pick = random.next();
            int typeIndex = pick < 0.45 ? 0 : (pick < 0.78 ? 1 : 2);
            TicketType type = types.get(typeIndex);
            int quantity = 1 + random.below(typeIndex == 2 ? 2 : 4);
            double fate = random.next();

            String id = "TK" + (10_000_000 + random.below(89_999_999));
            while (!ids.add(id)) {
                id = "TK" + (10_000_000 + random.below(89_999_999));
            }

            BookingStatus status = fate < 0.06
                    ? BookingStatus.CANCELLED
                    : (firstCheckIn != null && fate < 0.68 ? BookingStatus.CHECKED_IN : BookingStatus.OPEN);
            CheckIn checkIn = null;
            if (status == BookingStatus.CHECKED_IN) {
                minutes += (int) Math.floor(random.next() * 2.6);
                Staff by = random.next() < 0.55 ? dara : sreyneang;
                checkIn = new CheckIn(firstCheckIn.plusMinutes(minutes).atZone(zone).toInstant(), by.id(), by.name());
            }

            String buyerName = FIRST_NAMES[random.below(FIRST_NAMES.length)] + " "
                    + LAST_NAMES[random.below(LAST_NAMES.length)];
            // The mock writes 0xx xxx xxx; stored here in E.164.
            PhoneNumber phone = new PhoneNumber("+855" + (10 + random.below(89)) + (100 + random.below(900))
                    + (100 + random.below(900)));
            List<String> sizes = new ArrayList<>();
            if (withSizes) {
                for (int n = 0; n < quantity; n++) {
                    sizes.add(SIZES[random.below(SIZES.length)]);
                }
            }
            PaymentMethod payment = random.next() < 0.6 ? PaymentMethod.ABA_KHQR : PaymentMethod.CARD;

            bookings.add(Booking.restore(new BookingId(id), event.id(), buyerName, phone,
                    List.of(new BookingLine(type.name(), quantity)), type.price().times(quantity), payment,
                    SalesChannel.ONLINE, status, sizes, checkIn, bookedAt(event, i, count, id, zone, now)));
        }
        return bookings;
    }

    /**
     * When the {@code index}th of {@code count} bookings was made: on one of the
     * {@link #SALES_DAYS} days before sales closed, more of them nearer the close, as
     * sales pick up before an event; in the daytime, 08:00 to 22:00. Sales close an hour
     * before the event starts (before anyone checks in), or now for an event still to
     * come. Worked out from the position and the booking ID, not the generator, so the
     * buyers and booking IDs stay the app mock's.
     */
    static Instant bookedAt(Event event, int index, int count, String bookingId, ZoneId zone, Instant now) {
        Instant beforeEvent = event.startsAt().minusHours(1).atZone(zone).toInstant();
        Instant close = now.isBefore(beforeEvent) ? now : beforeEvent;
        // The square root of an even spread: denser towards 1, the closing day.
        double share = Math.sqrt((index + 0.5) / count);
        int day = (int) Math.floor(share * SALES_DAYS);
        LocalDate date = LocalDate.ofInstant(close, zone).minusDays(SALES_DAYS - 1 - day);
        int minuteOfDay = Math.floorMod(bookingId.hashCode(), DAYTIME_MINUTES);
        Instant at = date.atTime(8, 0).plusMinutes(minuteOfDay).atZone(zone).toInstant();
        // Booked on the closing day after it closed: just before it closed instead.
        return at.isBefore(close) ? at : close.minusSeconds(count - index);
    }

    static TicketType type(String name, long priceCents, int quantity) {
        return new TicketType(name, Money.ofCents(priceCents), quantity);
    }

    /** The mock's small repeatable random number generator, bit for bit. */
    private static final class Xorshift {

        private long state;

        Xorshift(long seed) {
            this.state = seed;
        }

        /** A number from 0 (inclusive) to 1 (exclusive). */
        double next() {
            state = (state ^ (state << 13)) & 0xFFFF_FFFFL;
            state ^= state >>> 17;
            state = (state ^ (state << 5)) & 0xFFFF_FFFFL;
            return state / 4_294_967_296.0;
        }

        int below(int limit) {
            return (int) Math.floor(next() * limit);
        }
    }
}
