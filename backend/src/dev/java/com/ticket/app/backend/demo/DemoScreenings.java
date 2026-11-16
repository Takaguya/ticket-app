package com.ticket.app.backend.demo;

import static com.ticket.app.backend.demo.SampleData.type;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.Screening;
import com.ticket.app.backend.event.domain.SeatLayout;

/**
 * The demo's cinema screenings: four films, the same as the user app's mock, shown at two
 * branches of Legend Cinema, the demo's cinema, over the next three days. Each has some seats
 * taken already.
 */
final class DemoScreenings {

    /** Legend Cinema, the demo's cinema (see {@link DemoMerchants}). */
    static final BusinessId LEGEND_CINEMA = new BusinessId(UUID.fromString("10000000-0000-7000-8000-000000000003"));

    private static final String AEON = "Legend Cinema, Aeon Mall";
    private static final String AEON_AREA = "Aeon Mall, Sihanouk Blvd, Phnom Penh";
    private static final String TK = "Legend Cinema, TK Avenue";
    private static final String TK_AREA = "TK Avenue, Phnom Penh";

    private static final String NEAK_TA = "A young archaeologist awakens an ancient guardian spirit beneath Phnom Kulen. "
            + "Khmer with English subtitles.";
    private static final String SKYLINE = "A courier on a stolen motorbike has 90 minutes to cross a locked-down city.";
    private static final String MOONS = "Two paper lanterns drift across Southeast Asia in search of the festival that "
            + "made them.";
    private static final String ROBOTS = "The robots are back, and this time the arena is underwater.";

    /**
     * @param seatsTaken how many seats the demo's bookings take
     * @param number     a small number that tells the demo screenings apart, for booking IDs
     */
    record Show(EventId id, int number, String film, String rating, String genre, int runtimeMinutes, String about,
                String theatre, String area, String hall, SeatLayout layout, int daysFromToday, LocalTime startsAt,
                long priceCents, int seatsTaken) {

        Event toEvent(BusinessId business, LocalDate today, BigDecimal commissionRate, Instant approvedAt) {
            return Event.restore(id, business, film, today.plusDays(daysFromToday).atTime(startsAt), theatre,
                    List.of(type(BusTrip.SEAT_TICKET, priceCents, layout.capacity())), commissionRate, approvedAt,
                    EventKind.CINEMA);
        }

        Screening toScreening() {
            return new Screening(id, film, rating, genre, runtimeMinutes, hall, layout);
        }

        EventPage toPage() {
            return new EventPage(id, area, about, "Non-refundable once seats are issued", List.of());
        }
    }

    static final List<Show> ALL = List.of(
            new Show(event(13), 1, "Neak Ta: The Guardian", "PG-13", "Khmer", 112, NEAK_TA, AEON, AEON_AREA,
                    "Hall 1", SeatLayout.HALL_STANDARD, 1, LocalTime.of(19, 0), 600, 30),
            new Show(event(14), 2, "Neak Ta: The Guardian", "PG-13", "Khmer", 112, NEAK_TA, AEON, AEON_AREA,
                    "Hall 1", SeatLayout.HALL_STANDARD, 2, LocalTime.of(14, 0), 500, 12),
            new Show(event(30), 3, "Neak Ta: The Guardian", "PG-13", "Khmer", 112, NEAK_TA, TK, TK_AREA,
                    "Hall 2", SeatLayout.HALL_SMALL, 1, LocalTime.of(20, 30), 600, 20),
            new Show(event(31), 4, "Skyline Run", "PG-13", "Action", 128, SKYLINE, AEON, AEON_AREA,
                    "Hall 2", SeatLayout.HALL_LARGE, 1, LocalTime.of(21, 0), 700, 45),
            new Show(event(32), 5, "Skyline Run", "PG-13", "Action", 128, SKYLINE, TK, TK_AREA,
                    "Hall 1", SeatLayout.HALL_STANDARD, 2, LocalTime.of(18, 30), 600, 18),
            new Show(event(33), 6, "Paper Moons", "G", "Animation", 94, MOONS, AEON, AEON_AREA,
                    "Hall 3", SeatLayout.HALL_SMALL, 1, LocalTime.of(10, 0), 400, 14),
            new Show(event(34), 7, "Paper Moons", "G", "Animation", 94, MOONS, TK, TK_AREA,
                    "Hall 1", SeatLayout.HALL_STANDARD, 3, LocalTime.of(11, 0), 400, 9),
            new Show(event(35), 8, "Robot Rumble 3", "PG", "Family", 106, ROBOTS, AEON, AEON_AREA,
                    "Hall 3", SeatLayout.HALL_SMALL, 2, LocalTime.of(15, 30), 500, 22),
            new Show(event(36), 9, "Robot Rumble 3", "PG", "Family", 106, ROBOTS, TK, TK_AREA,
                    "Hall 2", SeatLayout.HALL_STANDARD, 1, LocalTime.of(16, 0), 500, 33));

    private DemoScreenings() {
    }

    /** Online bookings that take the screening's seats, spread over the hall. Nobody is checked in. */
    static List<Booking> bookings(Show show, Event event, ZoneId zone, Instant now) {
        return DemoTrips.seated('8', show.number(), event, show.layout(), show.seatsTaken(), show.priceCents(), zone,
                now);
    }

    private static EventId event(int n) {
        return new EventId(UUID.fromString("30000000-0000-7000-8000-%012d".formatted(n)));
    }
}
