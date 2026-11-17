package com.ticket.app.backend.booking.service;

import java.util.List;

import com.ticket.app.backend.booking.model.AttemptId;
import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * A sale the owner makes at the entrance: tickets, the buyer's phone, cash or KHQR.
 *
 * @param attempt names this sale, so sending it again after a lost answer does not
 *                record it twice; null when the app sent none
 */
public record DoorSale(List<BookingLine> lines, PhoneNumber buyerPhone, PaymentMethod payment, AttemptId attempt) {
}
