package com.ticket.app.backend.booking.domain;

import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.EmailAddress;
import com.ticket.app.backend.shared.domain.PhoneNumber;

/**
 * Who runs a race. The organiser needs more than a name: the age group, the race kit's
 * shirt size and someone to call if something happens on the course.
 *
 * @param email where the e-ticket is also sent; null when not given
 */
public record Runner(String name, PhoneNumber phone, EmailAddress email, Gender gender, int age, String nationality,
                     String emergencyName, PhoneNumber emergencyPhone, ShirtSize shirtSize) {

    public static final int MIN_AGE = 5;
    public static final int MAX_AGE = 99;

    public Runner {
        name = name == null ? "" : name.strip();
        if (name.isEmpty()) {
            throw BusinessRuleException.invalid("Enter the runner's full name.");
        }
        if (name.length() > 80) {
            throw BusinessRuleException.invalid("Keep the runner's name under 80 characters.");
        }
        if (phone == null) {
            throw BusinessRuleException.invalid("Enter a valid phone number.");
        }
        if (gender == null) {
            throw BusinessRuleException.invalid("Choose the runner's gender.");
        }
        if (age < MIN_AGE || age > MAX_AGE) {
            throw BusinessRuleException.invalid("Enter an age from " + MIN_AGE + " to " + MAX_AGE + ".");
        }
        nationality = nationality == null ? "" : nationality.strip();
        if (nationality.isEmpty()) {
            throw BusinessRuleException.invalid("Enter the nationality.");
        }
        if (nationality.length() > 60) {
            throw BusinessRuleException.invalid("Keep the nationality under 60 characters.");
        }
        if (shirtSize == null) {
            throw BusinessRuleException.invalid("Choose a T-shirt size.");
        }
        emergencyName = emergencyName == null ? "" : emergencyName.strip();
        if (emergencyName.isEmpty()) {
            throw BusinessRuleException.invalid("Enter an emergency contact.");
        }
        if (emergencyName.length() > 80) {
            throw BusinessRuleException.invalid("Keep the emergency contact's name under 80 characters.");
        }
        if (emergencyPhone == null) {
            throw BusinessRuleException.invalid("Enter the emergency contact's phone number.");
        }
    }
}
