package com.ticket.app.backend.event.domain;

import java.time.Instant;
import java.util.Arrays;
import java.util.Objects;

/**
 * The cover image of an event: the processed picture, ready to show.
 *
 * @param data      the picture's bytes; never empty
 * @param updatedAt when the picture was last set; {@link #version()} is derived from it
 */
public record EventImage(EventId eventId, String contentType, byte[] data, Instant updatedAt) {

    /** Where an image is served from, without the server's address. */
    private static final String PATH = "/images/events/";

    public EventImage {
        Objects.requireNonNull(eventId, "eventId");
        Objects.requireNonNull(contentType, "contentType");
        Objects.requireNonNull(updatedAt, "updatedAt");
        if (data == null || data.length == 0) {
            throw new IllegalArgumentException("An image has no bytes.");
        }
        data = data.clone();
    }

    /** Milliseconds since 1970 of the last change: different for every new picture. */
    public long version() {
        return updatedAt.toEpochMilli();
    }

    /**
     * The address of the event's image, to put in JSON: {@code /images/events/<id>?v=<version>}. The
     * version makes a new picture a new address, so apps may keep each one for as long as they like.
     * Null when the event has no image ({@code version} is null).
     */
    public static String urlOf(EventId eventId, Long version) {
        return version == null ? null : PATH + eventId + "?v=" + version;
    }

    @Override
    public byte[] data() {
        return data.clone();
    }

    // A record compares arrays by identity: compare what is in them.
    @Override
    public boolean equals(Object other) {
        return other instanceof EventImage that && eventId.equals(that.eventId) && contentType.equals(that.contentType)
                && Arrays.equals(data, that.data) && updatedAt.equals(that.updatedAt);
    }

    @Override
    public int hashCode() {
        return Objects.hash(eventId, contentType, Arrays.hashCode(data), updatedAt);
    }

    @Override
    public String toString() {
        return "EventImage[" + eventId + ", " + contentType + ", " + data.length + " bytes, v" + version() + "]";
    }
}
