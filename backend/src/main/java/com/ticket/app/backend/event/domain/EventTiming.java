package com.ticket.app.backend.event.domain;

/** Where an event's day sits relative to today. Check-in is only open on the day. */
public enum EventTiming {
    PAST,
    TODAY,
    UPCOMING
}
