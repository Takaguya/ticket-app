package com.ticket.app.backend.identity.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * A new number registers as a buyer. {@code gender} is female, male or other;
 * {@code dateOfBirth} is written like {@code 1996-04-12}; {@code email} is optional.
 */
public record RegisterBuyerRequest(
        @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
        String name,
        @NotBlank(message = "Choose your gender.") String gender,
        @NotNull(message = "Enter your date of birth.") LocalDate dateOfBirth,
        String email) {
}
