package com.ticket.app.backend.admin.dto;

import com.ticket.app.backend.event.model.Event;

/** The event after an admin approved it. */
public record ApprovedEventResponse(String id, String name, boolean approved) {

    public static ApprovedEventResponse of(Event event) {
        return new ApprovedEventResponse(event.id().toString(), event.name(), event.isApproved());
    }
}
