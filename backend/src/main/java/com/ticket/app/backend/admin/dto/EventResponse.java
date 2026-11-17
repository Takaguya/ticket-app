package com.ticket.app.backend.admin.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.ticket.app.backend.admin.model.EventOverview;
import com.ticket.app.backend.event.model.EventImage;

/**
 * {@code status}: awaitingApproval, live, onSale, paused (its business is suspended) or ended.
 * {@code kind}: marathon, concert, show, bus, cinema or admission. A place (admission) is open
 * every day: its {@code startsAt} is only the day it was published, its {@code sold} counts every
 * day's tickets and its {@code capacity} is 0, because its limits are per day. {@code imageUrl} is the
 * event's cover image on this server, or null when it has none.
 */
public record EventResponse(String id, String name, String venue, LocalDateTime startsAt, String merchantId,
                     String merchantName, String status, int sold, int capacity, String kind, String imageUrl) {

    public static EventResponse of(EventOverview event, LocalDate today) {
        return new EventResponse(event.id().toString(), event.name(), event.venue(), event.startsAt(),
                event.merchantId().toString(), event.merchantName(), event.statusOn(today).code(), event.sold(),
                event.kind().isOpenEveryDay() ? 0 : event.capacity(), event.kind().code(),
                EventImage.urlOf(event.id(), event.imageVersion()));
    }
}
