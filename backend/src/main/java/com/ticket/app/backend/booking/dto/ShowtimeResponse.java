package com.ticket.app.backend.booking.dto;

import java.time.LocalDateTime;

import com.ticket.app.backend.booking.service.CinemaCatalogService.Showtime;
import com.ticket.app.backend.event.model.BusTrip;

/**
 * One screening of a film, matching the user app's Showtime. {@code id} is the screening's event ID: what
 * the buyer books. {@code startsAt} is local to Pin's time zone, without an offset.
 */
public record ShowtimeResponse(String id, LocalDateTime startsAt, String hall, long priceCents, int seatsLeft) {

    public static ShowtimeResponse of(Showtime showtime) {
        var screening = showtime.screening();
        long price = screening.event().ticketType(BusTrip.SEAT_TICKET).map(type -> type.price().cents())
                .orElse(0L);
        return new ShowtimeResponse(screening.event().id().toString(), screening.event().startsAt(),
                screening.screening().hall(), price, showtime.seatsLeft());
    }
}
