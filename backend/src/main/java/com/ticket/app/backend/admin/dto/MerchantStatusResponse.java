package com.ticket.app.backend.admin.dto;

import com.ticket.app.backend.business.model.Business;

/** The business after an admin changed its status. */
public record MerchantStatusResponse(String id, String name, String status) {

    public static MerchantStatusResponse of(Business business) {
        return new MerchantStatusResponse(business.id().toString(), business.name(), business.status().code());
    }
}
