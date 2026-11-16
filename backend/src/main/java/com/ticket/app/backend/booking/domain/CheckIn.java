package com.ticket.app.backend.booking.domain;

import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.business.domain.StaffId;

/**
 * When a booking was admitted and by whom. The name is kept as it was, so it
 * stays right if the member later leaves the team.
 */
public record CheckIn(Instant at, StaffId staffId, String staffName) {

    public CheckIn {
        Objects.requireNonNull(at, "at");
        Objects.requireNonNull(staffId, "staffId");
        Objects.requireNonNull(staffName, "staffName");
    }
}
