package com.ticket.app.backend.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * {@code netCents}: the amount the admin saw and sent. Refused (409) if what is owed
 * changed since, so the record always matches the money that went out.
 */
public record PayRequest(
        @NotBlank(message = "Choose the business to pay.") String merchantId,
        @NotNull(message = "Enter the amount paid.") @PositiveOrZero(message = "Enter the amount paid.")
        Long netCents) {
}
