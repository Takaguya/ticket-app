package com.ticket.app.backend.admin.dto;

import com.ticket.app.backend.event.model.EventImage;

/** An event's image after an admin set it: where it is now. */
public record ImageResponse(String imageUrl) {

    public static ImageResponse of(EventImage image) {
        return new ImageResponse(EventImage.urlOf(image.eventId(), image.version()));
    }
}
