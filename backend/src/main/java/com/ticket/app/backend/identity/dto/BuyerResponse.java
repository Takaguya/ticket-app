package com.ticket.app.backend.identity.dto;

import java.time.LocalDate;

import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.shared.model.EmailAddress;

/** {@code dateOfBirth} is written like {@code 1996-04-12}; {@code email} is null when none was given. */
public record BuyerResponse(String id, String name, String phone, String gender, LocalDate dateOfBirth, String email) {

    public static BuyerResponse of(Buyer buyer) {
        return new BuyerResponse(buyer.id().toString(), buyer.name(), buyer.phone().value(),
                buyer.gender().code(), buyer.dateOfBirth(), buyer.email().map(EmailAddress::value).orElse(null));
    }
}
