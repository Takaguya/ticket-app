package com.ticket.app.backend.booking.web;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.booking.application.CinemaCatalogService.Film;
import com.ticket.app.backend.booking.application.CinemaCatalogService.Showtime;
import com.ticket.app.backend.booking.application.CinemaCatalogService.TheatreShowtimes;
import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.Screening;

/**
 * JSON of the cinema endpoints, matching the user app's FilmListing, Theatre and Showtime.
 * {@code startsAt} is local to Pin's time zone, without an offset. Money is whole US cents.
 */
final class CinemaCatalogDtos {

    private CinemaCatalogDtos() {
    }

    /**
     * {@code id} names the film, e.g. {@code neak-ta-the-guardian}; {@code firstShowingOn} is a day.
     * {@code imageUrl} is the film's poster, or null.
     */
    record FilmResponse(String id, String name, String rating, String genre, int runtimeMinutes, String about,
                        String policy, long fromPriceCents, LocalDate firstShowingOn, String imageUrl) {

        static FilmResponse of(Film film) {
            return new FilmResponse(film.id(), film.title(), film.rating(), film.genre(), film.runtimeMinutes(),
                    film.about(), film.policy(), film.fromPriceCents(), film.firstShowing(), film.imageUrl());
        }
    }

    record TheatreResponse(String id, String name, String area) {
    }

    /** {@code id} is the screening's event ID: what the buyer books. */
    record ShowtimeResponse(String id, LocalDateTime startsAt, String hall, long priceCents, int seatsLeft) {

        static ShowtimeResponse of(Showtime showtime) {
            var screening = showtime.screening();
            long price = screening.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents())
                    .orElse(0L);
            return new ShowtimeResponse(screening.event().id().toString(), screening.event().startsAt(),
                    screening.screening().hall(), price, showtime.seatsLeft());
        }
    }

    record TheatreShowtimesResponse(TheatreResponse theatre, List<ShowtimeResponse> showtimes) {

        static TheatreShowtimesResponse of(TheatreShowtimes theatre) {
            return new TheatreShowtimesResponse(new TheatreResponse(theatre.id(), theatre.name(), theatre.area()),
                    theatre.showtimes().stream().map(ShowtimeResponse::of).toList());
        }
    }

    /**
     * What a booked screening adds to the event as a buyer sees it: the film (its name is the
     * event's), where it shows and how big the hall is. {@code hallSize} is small, standard or large.
     */
    record ScreeningJson(String filmId, String rating, String genre, int runtimeMinutes, String hall,
                         String hallSize, String hallLabel) {

        /** Null for an event that is not a screening. */
        static ScreeningJson of(Screening screening) {
            return screening == null ? null : new ScreeningJson(screening.filmId(), screening.rating(),
                    screening.genre(), screening.runtimeMinutes(), screening.hall(), screening.layout().code(),
                    screening.layout().label());
        }
    }
}
