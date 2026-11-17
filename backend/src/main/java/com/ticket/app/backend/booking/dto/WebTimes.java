package com.ticket.app.backend.booking.dto;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

/** How the booking endpoints write times: local to Pin's time zone, without an offset. */
public final class WebTimes {

    private WebTimes() {
    }

    /** Whole seconds: the database keeps microseconds, so finer times would differ once saved. */
    public static LocalDateTime local(Instant instant, ZoneId zone) {
        return LocalDateTime.ofInstant(instant, zone).truncatedTo(ChronoUnit.SECONDS);
    }
}
