package com.ticket.app.backend.booking.application;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.booking.domain.SeatBooking;
import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.event.application.CatalogService;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.SeatLayout;
import org.springframework.stereotype.Service;

/**
 * What a buyer sees of bus trips: the routes on offer, the trips on a day, and a trip's
 * seats with the ones already taken. A seat that live bookings hold is taken, and shows the
 * passenger's gender when it is known, as in the user app's design.
 */
@Service
public class BusCatalogService {

    private final CatalogService catalog;
    private final BookingRepository bookings;

    public BusCatalogService(CatalogService catalog, BookingRepository bookings) {
        this.catalog = catalog;
        this.bookings = bookings;
    }

    /**
     * A route with trips on sale.
     *
     * @param companies       how many bus companies run it
     * @param durationMinutes the shortest of its trips
     * @param fromPriceCents  the cheapest seat
     */
    public record Route(String origin, String destination, int trips, int companies, int durationMinutes,
                        long fromPriceCents) {
    }

    /** A trip on sale with the seats it has left. */
    public record Departure(EventOnSale trip, int seatsLeft) {
    }

    /** One seat on the map. {@code status}: available, taken, takenByFemale or takenByMale. */
    public record SeatView(String id, String label, String detail, String status) {
    }

    /** The trip's seats, front row first; a null in a row is the aisle. */
    public record SeatMap(String seatType, long priceCents, List<List<SeatView>> rows) {
    }

    /** Every route that has a trip on sale, the busiest first. */
    public List<Route> routes() {
        Map<String, List<EventOnSale>> byRoute = new LinkedHashMap<>();
        for (EventOnSale trip : catalog.busTripsOnSale()) {
            byRoute.computeIfAbsent(key(trip.bus().origin(), trip.bus().destination()), k -> new ArrayList<>())
                    .add(trip);
        }
        return byRoute.values().stream()
                .map(trips -> new Route(
                        trips.getFirst().bus().origin(),
                        trips.getFirst().bus().destination(),
                        trips.size(),
                        (int) trips.stream().map(EventOnSale::organiser).distinct().count(),
                        trips.stream().mapToInt(trip -> trip.bus().durationMinutes()).min().orElse(0),
                        trips.stream().mapToLong(trip -> price(trip)).min().orElse(0)))
                .sorted(Comparator.comparingInt(Route::trips).reversed()
                        .thenComparing(Route::origin).thenComparing(Route::destination))
                .toList();
    }

    /**
     * The trips from {@code origin} to {@code destination} on a day that have not left yet,
     * earliest first. Place names are matched ignoring case; no day means any day.
     */
    public List<Departure> departures(String origin, String destination, LocalDate day) {
        String route = key(origin, destination);
        List<EventOnSale> matching = catalog.busTripsOnSale().stream()
                .filter(trip -> key(trip.bus().origin(), trip.bus().destination()).equals(route))
                .filter(trip -> day == null || trip.event().startsAt().toLocalDate().equals(day))
                .toList();
        Map<EventId, Integer> taken = new HashMap<>();
        for (EventOnSale trip : matching) {
            taken.put(trip.event().id(), bookings.findHeldSeats(trip.event().id()).size());
        }
        return matching.stream()
                .map(trip -> new Departure(trip, Math.max(0, trip.bus().capacity() - taken.get(trip.event().id()))))
                .toList();
    }

    /** The seats of a trip on sale. Not found when it is not a bus trip or is no longer on sale. */
    public SeatMap seatMap(EventId tripId) {
        EventOnSale trip = catalog.busTripOnSale(tripId);
        return seatMap(trip.bus().layout(), price(trip), bookings.findHeldSeats(tripId));
    }

    static SeatMap seatMap(SeatLayout layout, long priceCents, List<SeatBooking> held) {
        Set<String> taken = new HashSet<>();
        Map<String, Gender> passengers = new HashMap<>();
        for (SeatBooking seat : held) {
            taken.add(seat.seatId());
            if (seat.passengerGender() != null) {
                passengers.put(seat.seatId(), seat.passengerGender());
            }
        }
        List<List<SeatView>> rows = layout.rows().stream()
                .map(row -> row.stream()
                        .map(spot -> spot == null ? null : new SeatView(spot.id(), spot.label(), spot.detail(),
                                // A hall's seats are only taken; a coach shows who sits where.
                                status(taken.contains(spot.id()),
                                        layout.isHall() ? null : passengers.get(spot.id()))))
                        .toList())
                .toList();
        return new SeatMap(layout.label(), priceCents, rows);
    }

    private static String status(boolean taken, Gender passenger) {
        if (!taken) {
            return "available";
        }
        if (passenger == Gender.FEMALE) {
            return "takenByFemale";
        }
        return passenger == Gender.MALE ? "takenByMale" : "taken";
    }

    /** The price of a seat on the trip: its one ticket type. */
    private static long price(EventOnSale trip) {
        return trip.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents()).orElse(0L);
    }

    private static String key(String origin, String destination) {
        return origin.strip().toLowerCase(Locale.ROOT) + "\u0000" + destination.strip().toLowerCase(Locale.ROOT);
    }
}
