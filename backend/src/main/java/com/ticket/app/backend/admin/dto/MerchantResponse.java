package com.ticket.app.backend.admin.dto;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

import com.ticket.app.backend.admin.model.MerchantOverview;

/** {@code owner} is null only if the owner's record is missing. */
public record MerchantResponse(String id, String name, String type, String status, OwnerResponse owner, int events,
                        long onlineSalesCents, long commissionCents, LocalDateTime registeredAt) {

    public static MerchantResponse of(MerchantOverview merchant, ZoneId zone) {
        return new MerchantResponse(merchant.id().toString(), merchant.name(), merchant.type().code(),
                merchant.status().code(),
                merchant.ownerIfKnown().map(o -> new OwnerResponse(o.name(), o.phone().value())).orElse(null),
                merchant.events(), merchant.onlineSales().cents(), merchant.commission().cents(),
                LocalDateTime.ofInstant(merchant.registeredAt(), zone).truncatedTo(ChronoUnit.SECONDS));
    }
}
