package com.ticket.app.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** A new number registers a business and becomes its owner. */
public record RegisterBusinessRequest(
        @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
        String businessName,
        String contactName,
        @NotBlank(message = "Choose what the business sells.") String type) {
}
