package com.ticket.app.backend.shared.service;

import java.time.Clock;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Counts requests per key (a client address) in one-minute windows and says
 * whether one more is allowed. Kept in memory, so each server instance counts for
 * itself: enough to slow down code guessing and SMS abuse.
 */
public final class RequestRateLimiter {

    private static final long MINUTE_MILLIS = 60_000;

    /** Past this many keys, windows from earlier minutes are dropped. */
    private static final int MAX_KEYS = 10_000;

    private record Window(long minute, int count) {
    }

    private final int limitPerMinute;
    private final Clock clock;
    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();

    public RequestRateLimiter(int limitPerMinute, Clock clock) {
        this.limitPerMinute = limitPerMinute;
        this.clock = clock;
    }

    /** Counts a request for {@code key}; false when it is over this minute's limit. */
    public boolean tryAcquire(String key) {
        long minute = clock.millis() / MINUTE_MILLIS;
        // compute() runs atomically per key, so parallel requests are all counted.
        Window window = windows.compute(key, (k, current) -> current == null || current.minute() != minute
                ? new Window(minute, 1)
                : new Window(minute, current.count() + 1));
        if (windows.size() > MAX_KEYS) {
            windows.values().removeIf(old -> old.minute() != minute);
        }
        return window.count() <= limitPerMinute;
    }
}
