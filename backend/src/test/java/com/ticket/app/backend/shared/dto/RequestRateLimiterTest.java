package com.ticket.app.backend.shared.dto;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;
import com.ticket.app.backend.shared.service.RequestRateLimiter;

public class RequestRateLimiterTest {

    private static final Instant START = Instant.parse("2026-11-13T02:00:00Z");

    @Test
    public void eachAddressGetsItsOwnLimitPerMinute() {
        var limiter = new RequestRateLimiter(3, Clock.fixed(START, ZoneOffset.UTC));

        assertThat(IntStream.range(0, 4).mapToObj(i -> limiter.tryAcquire("10.0.0.1")))
                .containsExactly(true, true, true, false);
        assertThat(limiter.tryAcquire("10.0.0.2")).isTrue();
    }

    @Test
    public void theCountStartsAgainTheNextMinute() {
        var clock = new MovableClock(START);
        var limiter = new RequestRateLimiter(1, clock);
        limiter.tryAcquire("10.0.0.1");
        assertThat(limiter.tryAcquire("10.0.0.1")).isFalse();

        clock.now = START.plus(Duration.ofMinutes(1));
        assertThat(limiter.tryAcquire("10.0.0.1")).isTrue();
    }

    /** A clock the test moves forward by hand. */
    private static final class MovableClock extends Clock {

        private Instant now;

        MovableClock(Instant now) {
            this.now = now;
        }

        @Override
        public Instant instant() {
            return now;
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }
    }

    @Test
    public void requestsArrivingTogetherAreAllCounted() {
        var limiter = new RequestRateLimiter(50, Clock.fixed(START, ZoneOffset.UTC));
        var allowed = new AtomicInteger();

        try (ExecutorService pool = Executors.newFixedThreadPool(16)) {
            for (int i = 0; i < 200; i++) {
                pool.submit(() -> {
                    if (limiter.tryAcquire("10.0.0.1")) {
                        allowed.incrementAndGet();
                    }
                });
            }
        }

        assertThat(allowed).hasValue(50);
    }
}
