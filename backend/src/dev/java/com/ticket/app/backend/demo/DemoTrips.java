package com.ticket.app.backend.demo;

import static com.ticket.app.backend.demo.SampleData.type;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.booking.model.SalesChannel;
import com.ticket.app.backend.booking.model.SeatBooking;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.buyer.model.Gender;
import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.SeatLayout;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * The demo's bus trips: tours from Phnom Penh to the provinces, run by Giant Ibis, the demo's
 * bus company. Each has some seats taken already, by bookings of one to four seats.
 */
final class DemoTrips {

    /** Giant Ibis, the demo's bus company (see {@link DemoMerchants}). */
    static final BusinessId GIANT_IBIS = new BusinessId(UUID.fromString("10000000-0000-7000-8000-000000000004"));

    private static final String TERMINAL = "Giant Ibis Terminal, Phnom Penh";
    private static final String TERMINAL_STREET = "St 106, Riverside, Phnom Penh";

    private static final String[] FIRST_NAMES = {
            "Sokha", "Dara", "Bopha", "Chanthy", "Vichea", "Sreymom", "Rithy", "Kunthea", "Piseth", "Sophea",
    };
    private static final String[] LAST_NAMES = {"Chan", "Keo", "Sok", "Meas", "Lim", "Heng", "Chea", "Ouk"};
    /** How many seats each booking takes, in turn. */
    private static final int[] PARTY_SIZES = {2, 1, 3, 1, 2, 2, 1, 4};

    /**
     * @param seatsTaken how many seats the demo's bookings take; 0 for none
     * @param number     a small number that tells the demo trips apart, for booking IDs
     */
    record Trip(EventId id, int number, String origin, String destination, int daysFromToday, LocalTime departs,
                int durationMinutes, SeatLayout layout, long priceCents, String boardingPoint, String about,
                List<String> amenities, int seatsTaken) {

        Event toEvent(BusinessId business, LocalDate today, BigDecimal commissionRate, Instant approvedAt) {
            BusTrip trip = toBusTrip();
            return Event.restore(id, business, trip.title(), today.plusDays(daysFromToday).atTime(departs),
                    boardingPoint, List.of(type(BusTrip.SEAT_TICKET, priceCents, layout.capacity())),
                    commissionRate, approvedAt, EventKind.BUS);
        }

        BusTrip toBusTrip() {
            return new BusTrip(id, origin, destination, durationMinutes, layout, amenities);
        }

        EventPage toPage() {
            return new EventPage(id, TERMINAL_STREET, about, "Refundable up to 48h before departure", List.of());
        }
    }

    static final List<Trip> ALL = List.of(
            new Trip(event(15), 1, "Phnom Penh", "Siem Reap", 1, LocalTime.of(8, 45), 360, SeatLayout.SEATER, 1500,
                    TERMINAL, "Two days at Angkor: Angkor Wat at sunrise, Bayon and Ta Prohm, with a hotel night in "
                    + "Siem Reap. Pick-up at the terminal.", List.of("Wi-Fi", "A/C", "Snack"), 22),
            new Trip(event(22), 2, "Phnom Penh", "Siem Reap", 4, LocalTime.of(8, 0), 360, SeatLayout.SEATER, 1400,
                    TERMINAL, "The weekend tour to Angkor, leaving early for the sunrise.",
                    List.of("A/C", "Water"), 9),
            new Trip(event(16), 3, "Phnom Penh", "Kampot", 3, LocalTime.of(14, 0), 210, SeatLayout.VIP, 1600,
                    TERMINAL, "Kampot pepper farms, a river boat at sunset and the old market, back the next "
                    + "evening.", List.of("Wi-Fi", "A/C", "Snack", "Blanket"), 12),
            new Trip(event(20), 4, "Phnom Penh", "Sihanoukville", 6, LocalTime.of(7, 30), 270, SeatLayout.SEATER,
                    1200, TERMINAL, "Island weekend: bus to Sihanoukville and the ferry to Koh Rong Samloem, "
                    + "two nights.", List.of("A/C", "Water"), 18),
            new Trip(event(21), 5, "Phnom Penh", "Mondulkiri", 9, LocalTime.of(21, 0), 480, SeatLayout.SLEEPER,
                    2200, TERMINAL, "Overnight sleeper to the Mondulkiri hills: waterfalls, elephant sanctuary and "
                    + "pine forest, three days.", List.of("Wi-Fi", "A/C", "Blanket", "Pillow"), 6));

    private DemoTrips() {
    }

    /**
     * The bookings that take the trip's seats: online bookings of one to four seats, the
     * seats spread over the coach, each showing a woman or a man. Nobody is checked in. They
     * were made over the weeks before now, like the other demo bookings.
     */
    static List<Booking> bookings(Trip trip, Event event, ZoneId zone, Instant now) {
        return seated('7', trip.number(), event, trip.layout(), trip.seatsTaken(), trip.priceCents(), zone, now);
    }

    /**
     * Online bookings that take {@code seatsTaken} seats of a coach or hall, spread over it. The
     * IDs are {@code TK}, {@code kind} (7 for bus trips, 8 for screenings), the trip's or
     * screening's {@code number} and the booking's number: unique among the demo's.
     */
    static List<Booking> seated(char kind, int number, Event event, SeatLayout layout, int seatsTaken,
                                long priceCents, ZoneId zone, Instant now) {
        List<String> order = scattered(layout);
        List<Integer> parties = new ArrayList<>();
        for (int taken = 0, i = 0; taken < seatsTaken; i++) {
            int party = Math.min(PARTY_SIZES[i % PARTY_SIZES.length], seatsTaken - taken);
            parties.add(party);
            taken += party;
        }

        List<Booking> bookings = new ArrayList<>();
        int next = 0;
        for (int i = 0; i < parties.size(); i++) {
            int party = parties.get(i);
            int person = number * 31 + i;
            String id = "TK%c%02d%03d00".formatted(kind, number, i);
            Gender gender = i % 2 == 0 ? Gender.FEMALE : Gender.MALE;
            List<SeatBooking> seats = new ArrayList<>();
            for (int s = 0; s < party; s++) {
                seats.add(new SeatBooking(order.get(next++), gender));
            }
            bookings.add(Booking.restore(new BookingId(id), event.id(), nameOf(person), phoneOf(person),
                    List.of(new BookingLine(BusTrip.SEAT_TICKET, party)), Money.ofCents(priceCents * party),
                    i % 2 == 0 ? PaymentMethod.ABA_KHQR : PaymentMethod.CARD, SalesChannel.ONLINE,
                    BookingStatus.OPEN, List.of(), null, null, null, seats,
                    SampleData.bookedAt(event, i, parties.size(), id, zone, now)));
        }
        return bookings;
    }

    /** A made-up buyer's name, the same for the same {@code person}. */
    static String nameOf(int person) {
        return FIRST_NAMES[person % FIRST_NAMES.length] + " " + LAST_NAMES[(person / 3) % LAST_NAMES.length];
    }

    /** A made-up Cambodian mobile number, the same for the same {@code person}. */
    static PhoneNumber phoneOf(int person) {
        return new PhoneNumber("+855" + (10 + person % 89) + (100 + person * 7 % 900) + (100 + person * 13 % 900));
    }

    /** The coach's seats in a fixed order that is not front to back, so taken seats are spread out. */
    private static List<String> scattered(SeatLayout layout) {
        List<String> seats = layout.seatIds();
        List<String> order = new ArrayList<>();
        // 7 shares no factor with 40, 30, 16, 48, 80 or 120 seats, so this visits every seat once.
        for (int i = 0; i < seats.size(); i++) {
            order.add(seats.get(i * 7 % seats.size()));
        }
        return order;
    }

    private static EventId event(int n) {
        return new EventId(UUID.fromString("30000000-0000-7000-8000-%012d".formatted(n)));
    }
}
