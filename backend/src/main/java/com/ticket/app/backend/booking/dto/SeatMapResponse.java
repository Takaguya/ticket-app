package com.ticket.app.backend.booking.dto;

import java.util.List;

import com.ticket.app.backend.booking.service.BusCatalogService.SeatMap;

/** {@code status}: available, taken, takenByFemale or takenByMale. A null in a row is the aisle. */
public record SeatMapResponse(String seatType, long priceCents, List<List<SeatResponse>> rows) {

    public static SeatMapResponse of(SeatMap map) {
        return new SeatMapResponse(map.seatType(), map.priceCents(), map.rows().stream()
                .map(row -> row.stream().map(seat -> seat == null ? null : SeatResponse.of(seat)).toList())
                .toList());
    }
}
