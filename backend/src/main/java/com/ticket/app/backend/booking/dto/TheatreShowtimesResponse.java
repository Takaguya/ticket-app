package com.ticket.app.backend.booking.dto;

import java.util.List;

import com.ticket.app.backend.booking.service.CinemaCatalogService.TheatreShowtimes;

/** A cinema's showtimes of one film. */
public record TheatreShowtimesResponse(TheatreResponse theatre, List<ShowtimeResponse> showtimes) {

    public static TheatreShowtimesResponse of(TheatreShowtimes theatre) {
        return new TheatreShowtimesResponse(new TheatreResponse(theatre.id(), theatre.name(), theatre.area()),
                theatre.showtimes().stream().map(ShowtimeResponse::of).toList());
    }
}
