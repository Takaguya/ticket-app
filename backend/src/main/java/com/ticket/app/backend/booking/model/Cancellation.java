package com.ticket.app.backend.booking.model;

import java.time.Instant;
import java.util.Objects;

import com.ticket.app.backend.business.model.StaffId;

/**
 * When the business cancelled a booking, who did, and why. The name is kept as it
 * was, like a check-in's, so it stays right if the owner later leaves the team.
 */
public record Cancellation(Instant at, StaffId staffId, String staffName, CancelReason reason) {

    public Cancellation {
        Objects.requireNonNull(at, "at");
        Objects.requireNonNull(staffId, "staffId");
        Objects.requireNonNull(staffName, "staffName");
        Objects.requireNonNull(reason, "reason");
    }
}
