package com.ticket.app.backend.booking.dto;

import static com.ticket.app.backend.booking.dto.WebTimes.local;

import java.time.LocalDateTime;
import java.time.ZoneId;

import com.ticket.app.backend.booking.model.CheckIn;

/** Null when the booking is not checked in. */
public record CheckInResponse(LocalDateTime at, String staffName) {

    public static CheckInResponse of(CheckIn checkIn, ZoneId zone) {
        return checkIn == null ? null : new CheckInResponse(local(checkIn.at(), zone), checkIn.staffName());
    }
}
