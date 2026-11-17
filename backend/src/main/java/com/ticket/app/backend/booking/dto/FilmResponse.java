package com.ticket.app.backend.booking.dto;

import java.time.LocalDate;

import com.ticket.app.backend.booking.service.CinemaCatalogService.Film;

/**
 * A film with a screening on sale, matching the user app's FilmListing.
 * {@code id} names the film, e.g. {@code neak-ta-the-guardian}; {@code firstShowingOn} is a day.
 * {@code imageUrl} is the film's poster, or null. Money is whole US cents.
 */
public record FilmResponse(String id, String name, String rating, String genre, int runtimeMinutes, String about,
                    String policy, long fromPriceCents, LocalDate firstShowingOn, String imageUrl) {

    public static FilmResponse of(Film film) {
        return new FilmResponse(film.id(), film.title(), film.rating(), film.genre(), film.runtimeMinutes(),
                film.about(), film.policy(), film.fromPriceCents(), film.firstShowing(), film.imageUrl());
    }
}
