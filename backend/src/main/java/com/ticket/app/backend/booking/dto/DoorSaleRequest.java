package com.ticket.app.backend.booking.dto;

import java.util.List;

import com.ticket.app.backend.booking.service.DoorSale;
import com.ticket.app.backend.booking.model.AttemptId;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.shared.model.PhoneNumber;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/** {@code attemptId}: a UUID for this sale, sent again on retries. Optional. */
public record DoorSaleRequest(
        @NotNull(message = "Choose at least one ticket.") List<@NotNull(message = "Choose at least one ticket.") @Valid LineJson> lines,
        @NotBlank(message = "Enter the buyer's phone number.") String buyerPhone,
        @NotBlank(message = "Choose how the buyer pays.") String payment,
        String attemptId) {

    public DoorSale toDoorSale() {
        return new DoorSale(lines.stream().map(LineJson::toLine).toList(), PhoneNumber.of(buyerPhone),
                PaymentMethod.fromCode(payment), AttemptId.parseOptional(attemptId).orElse(null));
    }
}
