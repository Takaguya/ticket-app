package com.ticket.app.backend.booking.application;

import java.util.List;

import com.ticket.app.backend.booking.domain.AttemptId;
import com.ticket.app.backend.booking.domain.BookingLine;
import com.ticket.app.backend.booking.domain.PaymentMethod;
import com.ticket.app.backend.shared.domain.PhoneNumber;

/**
 * A sale the owner makes at the entrance: tickets, the buyer's phone, cash or KHQR.
 *
 * @param attempt names this sale, so sending it again after a lost answer does not
 *                record it twice; null when the app sent none
 */
public record DoorSale(List<BookingLine> lines, PhoneNumber buyerPhone, PaymentMethod payment, AttemptId attempt) {
}
