package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.model.CancelReason;
import jakarta.validation.constraints.NotBlank;

/** {@code reason}: buyerAsked, eventChanged, soldByMistake or other. */
public record CancelRequest(@NotBlank(message = "Choose why the booking is cancelled.") String reason) {

    public CancelReason toReason() {
        return CancelReason.fromCode(reason);
    }
}
