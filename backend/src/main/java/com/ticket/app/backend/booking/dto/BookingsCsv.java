package com.ticket.app.backend.booking.dto;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.CheckIn;
import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.shared.model.Money;

/**
 * The owner's bookings export for one event: the same columns as the merchant
 * app's CSV. Amounts have no currency sign so spreadsheets read them as numbers.
 */
public final class BookingsCsv {

    private static final List<String> COLUMNS = List.of(
            "Booking ID", "Name", "Phone", "Tickets", "Category", "T-shirt sizes", "Total (USD)",
            "Pin commission (USD)", "You receive (USD)", "Payment", "Sold", "Status", "Checked in at",
            "Checked in by", "Runner", "Runner phone", "Runner email", "Runner gender", "Runner age",
            "Runner nationality", "Emergency contact", "Emergency phone", "Visit date");

    private static final DateTimeFormatter CHECK_IN_TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    /** The byte order mark makes Excel read the file as UTF-8. */
    private static final String BOM = "﻿";

    private BookingsCsv() {
    }

    /** e.g. {@code phnom-penh-half-marathon-2026-bookings-checked-in.csv} */
    public static String fileName(Event event, BookingStatus status) {
        String suffix = status == null ? "" : "-" + slug(status.label());
        return slug(event.name()) + "-bookings" + suffix + ".csv";
    }

    public static String content(Event event, List<Booking> bookings, ZoneId zone) {
        Stream<List<String>> rows = Stream.concat(
                Stream.of(COLUMNS),
                bookings.stream().map(booking -> row(booking, event, zone)));
        return BOM + rows
                .map(row -> row.stream().map(BookingsCsv::quote).collect(Collectors.joining(",")))
                .collect(Collectors.joining("\r\n"));
    }

    private static List<String> row(Booking booking, Event event, ZoneId zone) {
        Money commission = booking.commission(event.commissionRate());
        // The business is paid on the full price: Pin pays for promo codes.
        Money received = booking.countsAsSold() ? booking.subtotal().minus(commission) : Money.ZERO;
        CheckIn checkIn = booking.checkIn();
        Runner runner = booking.purchase() == null ? null : booking.purchase().runner();
        return List.of(
                booking.id().value(),
                booking.buyerName(),
                booking.phone().value(),
                String.valueOf(booking.ticketCount()),
                booking.summary(),
                String.join(" ", booking.tshirtSizes()),
                booking.subtotal().toPlainString(),
                commission.toPlainString(),
                received.toPlainString(),
                booking.payment().label(),
                booking.channel().label(),
                booking.status().label(),
                checkIn == null ? "" : LocalDateTime.ofInstant(checkIn.at(), zone).format(CHECK_IN_TIME),
                checkIn == null ? "" : checkIn.staffName(),
                runner == null ? "" : runner.name(),
                runner == null ? "" : runner.phone().value(),
                runner == null || runner.email() == null ? "" : runner.email().value(),
                runner == null ? "" : runner.gender().code(),
                runner == null ? "" : String.valueOf(runner.age()),
                runner == null ? "" : runner.nationality(),
                runner == null ? "" : runner.emergencyName(),
                runner == null ? "" : runner.emergencyPhone().value(),
                // The day a place's tickets are for, e.g. 2026-11-28; empty for any other event.
                booking.visitDate() == null ? "" : booking.visitDate().toString());
    }

    private static String quote(String value) {
        return '"' + value.replace("\"", "\"\"") + '"';
    }

    private static String slug(String text) {
        return text.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-").replaceAll("^-+|-+$", "");
    }
}
