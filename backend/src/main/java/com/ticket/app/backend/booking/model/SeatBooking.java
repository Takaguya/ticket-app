package com.ticket.app.backend.booking.model;

import java.util.Objects;

import com.ticket.app.backend.buyer.model.Gender;

/**
 * A seat of a bus trip that a booking holds, e.g. {@code 3A}. The passenger's gender is shown
 * on the seat map to other buyers, as in the user app's design; a seat sold at the door has
 * none.
 *
 * @param passengerGender null when unknown
 */
public record SeatBooking(String seatId, Gender passengerGender) {

    public SeatBooking {
        Objects.requireNonNull(seatId, "seatId");
    }
}
