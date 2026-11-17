package com.ticket.app.backend.booking.dto;

import java.time.LocalDate;
import java.util.List;

import com.ticket.app.backend.booking.service.OnlineOrder;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * What a buyer sends to book, matching the user app's order. {@code payment} is abaKhqr or card;
 * {@code promoCode} and {@code runner} are optional (a race needs its runner); {@code saveRunner}
 * keeps the runner for the buyer's next race. A bus trip or a screening is booked with {@code seats}
 * (ids such as {@code 3A} or {@code F5}) instead of {@code lines}; a place with {@code visitDate}, the
 * day the tickets are for.
 */
public record BuyBookingRequest(
        @NotBlank(message = "Choose an event.") String eventId,
        List<@NotNull(message = "Choose at least one ticket.") @Valid LineJson> lines,
        List<String> seats,
        @NotBlank(message = "Choose how to pay.") String payment,
        String promoCode,
        @Valid RunnerJson runner,
        Boolean saveRunner,
        LocalDate visitDate) {

    public OnlineOrder toOrder() {
        return new OnlineOrder(EventId.parse(eventId),
                lines == null ? List.of() : lines.stream().map(LineJson::toLine).toList(),
                payment(payment), promoCode, runner == null ? null : runner.toInput(),
                Boolean.TRUE.equals(saveRunner), seats == null ? List.of() : seats, visitDate);
    }

    /** Anything but the API's payment names is refused as "Choose how to pay.", not the door sale's wording. */
    private static PaymentMethod payment(String code) {
        try {
            return PaymentMethod.fromCode(code);
        } catch (BusinessRuleException e) {
            throw BusinessRuleException.invalid("Choose how to pay.");
        }
    }
}
