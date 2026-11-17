package com.ticket.app.backend.identity.dto;

import com.ticket.app.backend.business.model.Business;

/** {@code status}: pending (waiting for Pin's approval), active or suspended. */
public record BusinessResponse(String id, String name, String type, String status) {

    public static BusinessResponse of(Business business) {
        return new BusinessResponse(business.id().toString(), business.name(), business.type().code(),
                business.status().code());
    }
}
