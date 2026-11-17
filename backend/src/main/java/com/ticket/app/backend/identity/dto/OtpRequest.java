package com.ticket.app.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/** {@code purpose} is login or register; it only changes wording in the app. */
public record OtpRequest(
        @NotBlank(message = "Enter a valid phone number.") String phone,
        @Pattern(regexp = "login|register") String purpose) {
}
