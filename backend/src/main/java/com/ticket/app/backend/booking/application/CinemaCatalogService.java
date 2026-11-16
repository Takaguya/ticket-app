package com.ticket.app.backend.booking.application;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

import com.ticket.app.backend.booking.application.BusCatalogService.SeatMap;
import com.ticket.app.backend.booking.domain.BookingRepository;
import com.ticket.app.backend.event.application.CatalogService;
import com.ticket.app.backend.event.application.EventOnSale;
import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.Screening;
import com.ticket.app.backend.shared.domain.NotFoundException;
import org.springframework.stereotype.Service;

/**
 * What a buyer sees of the cinema: the films with a screening on sale, a film's showtimes on a
 * day by cinema, and a screening's seats with the ones already taken. Screenings with the same
 * film title are the same film.
 */
@Service
public class CinemaCatalogService {

    private final CatalogService catalog;
    private final BookingRepository bookings;

    public CinemaCatalogService(CatalogService catalog, BookingRepository bookings) {
        this.catalog = catalog;
        this.bookings = bookings;
    }

    /**
     * A film with a screening on sale.
     *
     * @param about          from the film's first screening
     * @param policy         refunds and transfers, from the film's first screening
     * @param fromPriceCents the cheapest seat of any of its screenings
     * @param firstShowing   the day of its first screening on sale
     * @param imageUrl       the film's poster: the cover image of its first screening that has one, or null
     */
    public record Film(String id, String title, String rating, String genre, int runtimeMinutes, String about,
                       String policy, long fromPriceCents, LocalDate firstShowing, String imageUrl) {
    }

    /** A screening on sale with the seats it has left. */
    public record Showtime(EventOnSale screening, int seatsLeft) {
    }

    /**
     * A cinema's showtimes of one film.
     *
     * @param id   names the cinema, e.g. {@code legend-cinema-aeon-mall}
     * @param area where it is; may be empty
     */
    public record TheatreShowtimes(String id, String name, String area, List<Showtime> showtimes) {
    }

    /** Every film that has a screening on sale, the one showing soonest first. */
    public List<Film> films() {
        Map<String, List<EventOnSale>> byFilm = new LinkedHashMap<>();
        for (EventOnSale screening : catalog.screeningsOnSale()) {
            byFilm.computeIfAbsent(screening.screening().filmId(), k -> new ArrayList<>()).add(screening);
        }
        return byFilm.values().stream().map(CinemaCatalogService::describe).toList();
    }

    /** One film with a screening on sale. Not found when it has none (any more). */
    public Film film(String filmId) {
        return films().stream()
                .filter(film -> film.id().equals(filmId))
                .findFirst()
                .orElseThrow(() -> new NotFoundException("This film is not showing."));
    }

    /**
     * The film's screenings that have not started, by cinema, earliest first. No day means any day.
     * Empty when the film has none.
     */
    public List<TheatreShowtimes> showtimes(String filmId, LocalDate day) {
        Map<String, List<EventOnSale>> byTheatre = new LinkedHashMap<>();
        for (EventOnSale screening : catalog.screeningsOnSale()) {
            boolean wanted = screening.screening().filmId().equals(filmId)
                    && (day == null || screening.event().startsAt().toLocalDate().equals(day));
            if (wanted) {
                byTheatre.computeIfAbsent(theatreId(screening), k -> new ArrayList<>()).add(screening);
            }
        }
        return byTheatre.entrySet().stream()
                .map(entry -> {
                    EventOnSale first = entry.getValue().getFirst();
                    List<Showtime> showtimes = entry.getValue().stream()
                            .map(screening -> new Showtime(screening, seatsLeft(screening)))
                            .toList();
                    return new TheatreShowtimes(entry.getKey(), first.event().venue(), first.page().venueDetail(),
                            showtimes);
                })
                .sorted(Comparator.comparing(TheatreShowtimes::name))
                .toList();
    }

    /** The seats of a screening on sale. Not found when it is not a screening or is no longer on sale. */
    public SeatMap seatMap(EventId screeningId) {
        EventOnSale screening = catalog.screeningOnSale(screeningId);
        return BusCatalogService.seatMap(screening.layout(), price(screening), bookings.findHeldSeats(screeningId));
    }

    private int seatsLeft(EventOnSale screening) {
        return Math.max(0, screening.screening().capacity() - bookings.findHeldSeats(screening.event().id()).size());
    }

    /** {@code legend-cinema-aeon-mall}: the cinema's name as a word list. */
    static String theatreId(EventOnSale screening) {
        return Screening.slug(screening.event().venue().toLowerCase(Locale.ROOT));
    }

    /** The film as its screenings on sale show it; the first of them gives the details. */
    private static Film describe(List<EventOnSale> screenings) {
        EventOnSale first = screenings.getFirst();
        Screening film = first.screening();
        return new Film(film.filmId(), film.filmTitle(), film.rating(), film.genre(), film.runtimeMinutes(),
                first.page().about(), first.page().policy(),
                screenings.stream().mapToLong(CinemaCatalogService::price).min().orElse(0),
                first.event().startsAt().toLocalDate(),
                screenings.stream().map(EventOnSale::imageUrl).filter(Objects::nonNull).findFirst().orElse(null));
    }

    private static long price(EventOnSale screening) {
        return screening.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents()).orElse(0L);
    }
}
