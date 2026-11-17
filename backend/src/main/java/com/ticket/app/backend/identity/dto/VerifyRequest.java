package com.ticket.app.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** {@code app} is merchant or user. */
public record VerifyRequest(
        @NotBlank(message = "Enter a valid phone number.") String phone,
        @NotBlank(message = "Enter the 6-digit code.")
        @Pattern(regexp = "[0-9]{6}", message = "Enter the 6-digit code.") String code,
        @Pattern(regexp = "login|register") String purpose,
        @Pattern(regexp = "merchant|user") String app) {
}
