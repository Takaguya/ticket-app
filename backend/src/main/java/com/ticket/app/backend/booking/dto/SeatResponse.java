package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.service.BusCatalogService.SeatView;

/** One seat of a coach or hall. */
public record SeatResponse(String id, String label, String detail, String status) {

    public static SeatResponse of(SeatView seat) {
        return new SeatResponse(seat.id(), seat.label(), seat.detail(), seat.status());
    }
}
