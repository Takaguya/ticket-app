package com.ticket.app.backend.booking.service;

import com.ticket.app.backend.booking.model.Runner;
import com.ticket.app.backend.booking.model.ShirtSize;
import com.ticket.app.backend.buyer.model.Gender;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.EmailAddress;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * The runner as the buyer sent them, not checked yet. An order carries it unchecked
 * because only a race needs a runner: for any other event it is ignored, and only
 * {@link #toRunner()} refuses what is wrong with it.
 *
 * @param gender    female, male or other
 * @param shirtSize XS, S, M, L or XL
 */
public record RunnerInput(String name, String phone, String email, String gender, Integer age, String nationality,
                          String emergencyName, String emergencyPhone, String shirtSize) {

    /** The checked runner; refused with the first thing that is missing or wrong. */
    public Runner toRunner() {
        return new Runner(name, phoneOrNull(phone), email == null || email.isBlank() ? null : EmailAddress.of(email),
                gender == null ? null : runnerGender(gender), age == null ? 0 : age, nationality, emergencyName,
                phoneOrNull(emergencyPhone), shirtSize == null ? null : ShirtSize.fromCode(shirtSize));
    }

    /** Null when none was given, so the runner's own rules say what is missing. */
    private static PhoneNumber phoneOrNull(String text) {
        return text == null || text.isBlank() ? null : PhoneNumber.of(text);
    }

    private static Gender runnerGender(String code) {
        try {
            return Gender.fromCode(code);
        } catch (BusinessRuleException e) {
            throw BusinessRuleException.invalid("Choose the runner's gender.");
        }
    }
}
