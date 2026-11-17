package com.ticket.app.backend.booking.controller;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;

import com.ticket.app.backend.booking.service.CinemaCatalogService;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.booking.dto.FilmResponse;
import com.ticket.app.backend.booking.dto.SeatMapResponse;
import com.ticket.app.backend.booking.dto.TheatreShowtimesResponse;

/** The films a signed-in buyer can book: what is showing, showtimes by cinema and a screening's seats. */
@RestController
@RequestMapping("/catalog/cinema")
class CinemaCatalogController {

    private final CinemaCatalogService cinema;

    CinemaCatalogController(CinemaCatalogService cinema) {
        this.cinema = cinema;
    }

    /** Every film with a screening on sale, the one showing soonest first. */
    @GetMapping("/films")
    List<FilmResponse> films() {
        return cinema.films().stream().map(FilmResponse::of).toList();
    }

    /** One film; 404 when it has no screening on sale. */
    @GetMapping("/films/{filmId}")
    FilmResponse film(@PathVariable String filmId) {
        return FilmResponse.of(cinema.film(filmId));
    }

    /**
     * The film's screenings that have not started, by cinema.
     *
     * @param date a day such as {@code 2026-11-28}; all days when left out
     */
    @GetMapping("/films/{filmId}/showtimes")
    List<TheatreShowtimesResponse> showtimes(@PathVariable String filmId,
                                             @RequestParam(required = false) String date) {
        return cinema.showtimes(filmId, day(date)).stream().map(TheatreShowtimesResponse::of).toList();
    }

    /** The screening's seats and which are taken; 404 when it is not a screening on sale. */
    @GetMapping("/showtimes/{showtimeId}/seats")
    SeatMapResponse seats(@PathVariable String showtimeId) {
        return SeatMapResponse.of(cinema.seatMap(EventId.parse(showtimeId)));
    }

    private static LocalDate day(String date) {
        if (date == null || date.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(date.strip());
        } catch (DateTimeParseException e) {
            throw BusinessRuleException.invalid("Write the day like 2026-11-28.");
        }
    }
}
