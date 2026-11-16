package com.ticket.app.backend.demo;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.booking.domain.Booking;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.SalesSummary;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.shared.domain.Money;
import org.junit.jupiter.api.Test;

/**
 * The demo data must match the merchant app's mock backend, so both show the same
 * business. The expected numbers are what the app shows on its Today screen.
 */
class SampleDataTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 11, 12);
    private static final ZoneId ZONE = ZoneId.of("Asia/Phnom_Penh");

    @Test
    void todaysEventMatchesTheAppMock() {
        Event marathon = SampleData.marathon(DemoDataSeeder.MARATHON, DemoDataSeeder.BUSINESS, TODAY,
                BigDecimal.valueOf(5), Instant.parse("2026-11-12T00:00:00Z"));
        List<Booking> bookings = SampleData.bookings(marathon, 64, 20261018, TODAY.atTime(4, 30), true,
                new SampleData.Staff(DemoDataSeeder.DARA, "Dara Keo"),
                new SampleData.Staff(DemoDataSeeder.SREYNEANG, "Sreyneang Lim"),
                ZONE, Instant.parse("2026-11-12T00:00:00Z"));

        SalesSummary summary = SalesSummary.of(marathon, bookings);
        assertThat(summary.checkedIn()).isEqualTo(90);
        assertThat(summary.sold()).isEqualTo(134);
        assertThat(summary.left()).isEqualTo(86);
        assertThat(summary.bookingCount()).isEqualTo(60);
        assertThat(summary.online()).isEqualTo(Money.ofCents(214_100));

        Booking bopha = bookings.stream()
                .filter(booking -> booking.id().equals(new BookingId("TK88900882")))
                .findFirst()
                .orElseThrow();
        assertThat(bopha.buyerName()).isEqualTo("Bopha Keo");
        assertThat(bopha.summary()).isEqualTo("4× 10K");
        assertThat(bopha.phone().localDigits()).isEqualTo("049890835");
        assertThat(bopha.tshirtSizes()).containsExactly("S", "M", "L", "XS");
    }

    @Test
    void ticketsForAnEventToComeWereBoughtOverTheLastSixWeeksMostlyLately() {
        Instant now = Instant.parse("2026-11-12T08:00:00Z");
        Event kampot = SampleData.kampot(DemoDataSeeder.KAMPOT, DemoDataSeeder.BUSINESS, TODAY,
                BigDecimal.valueOf(5), now);
        List<Booking> bookings = SampleData.bookings(kampot, 110, 77123, null, false, STAFF, STAFF, ZONE, now);

        assertThat(bookings).allSatisfy(booking -> assertThat(booking.createdAt())
                .isBefore(now)
                .isAfterOrEqualTo(now.minus(Duration.ofDays(SampleData.SALES_DAYS))));
        long lastTwoWeeks = bookings.stream()
                .filter(booking -> booking.createdAt().isAfter(now.minus(Duration.ofDays(14))))
                .count();
        assertThat(lastTwoWeeks).isGreaterThan(bookings.size() / 2);
        assertThat(bookings.stream().map(Booking::createdAt).distinct().count()).isEqualTo(bookings.size());
        assertThat(bookings).allSatisfy(booking -> assertThat(booking.createdAt().atZone(ZONE).getHour())
                .isBetween(8, 21));
    }

    @Test
    void ticketsWereBoughtBeforeTheEventAndBeforeTheirCheckIn() {
        Instant now = Instant.parse("2026-11-12T08:00:00Z");
        Event nightRun = SampleData.nightRun(DemoDataSeeder.NIGHT_RUN, DemoDataSeeder.BUSINESS, TODAY,
                BigDecimal.valueOf(5), now);
        Event marathon = SampleData.marathon(DemoDataSeeder.MARATHON, DemoDataSeeder.BUSINESS, TODAY,
                BigDecimal.valueOf(5), now);

        for (Event event : List.of(nightRun, marathon)) {
            LocalDateTime firstCheckIn = event.startsAt().minusHours(1);
            Instant start = event.startsAt().atZone(ZONE).toInstant();
            List<Booking> bookings = SampleData.bookings(event, 90, 51877, firstCheckIn, true, STAFF, STAFF, ZONE,
                    now);
            assertThat(bookings).allSatisfy(booking -> {
                assertThat(booking.createdAt()).isBefore(start);
                if (booking.checkIn() != null) {
                    assertThat(booking.createdAt()).isBefore(booking.checkIn().at());
                }
            });
        }
    }

    private static final SampleData.Staff STAFF = new SampleData.Staff(DemoDataSeeder.DARA, "Dara Keo");
}
