package com.ticket.app.backend.buyer.domain;

import java.time.LocalDate;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.EmailAddress;
import com.ticket.app.backend.shared.domain.PhoneNumber;

/**
 * A person who books tickets in the user app, with the details the app asks when
 * their number is new. Also who is signed in: controllers receive it as
 * {@code @AuthenticationPrincipal Buyer me}.
 */
public final class Buyer {

    static final int MAX_NAME_LENGTH = 80;

    private final BuyerId id;
    private final String name;
    private final PhoneNumber phone;
    private final Gender gender;
    private final LocalDate dateOfBirth;
    private final EmailAddress email;

    private Buyer(BuyerId id, String name, PhoneNumber phone, Gender gender, LocalDate dateOfBirth,
                  EmailAddress email) {
        this.id = Objects.requireNonNull(id, "id");
        this.name = Objects.requireNonNull(name, "name");
        this.phone = Objects.requireNonNull(phone, "phone");
        this.gender = Objects.requireNonNull(gender, "gender");
        this.dateOfBirth = Objects.requireNonNull(dateOfBirth, "dateOfBirth");
        this.email = email;
    }

    /**
     * A new account for a confirmed phone number. The rules: a name of 1 to 80
     * characters, a gender, a date of birth that is not in the future, and an email
     * address that is valid when given.
     *
     * @param email blank for none
     * @param today today where the buyer lives
     */
    public static Buyer register(PhoneNumber phone, String name, Gender gender, LocalDate dateOfBirth, String email,
                                 LocalDate today) {
        String cleanName = name == null ? "" : name.strip();
        if (cleanName.isEmpty()) {
            throw BusinessRuleException.invalid("Enter your name.");
        }
        if (cleanName.length() > MAX_NAME_LENGTH) {
            throw BusinessRuleException.invalid("Keep your name under 80 characters.");
        }
        if (gender == null) {
            throw BusinessRuleException.invalid("Choose your gender.");
        }
        if (dateOfBirth == null) {
            throw BusinessRuleException.invalid("Enter your date of birth.");
        }
        if (dateOfBirth.isAfter(today)) {
            throw BusinessRuleException.invalid("Your date of birth cannot be in the future.");
        }
        EmailAddress cleanEmail = email == null || email.isBlank() ? null : EmailAddress.of(email);
        return new Buyer(BuyerId.newId(), cleanName, phone, gender, dateOfBirth, cleanEmail);
    }

    /** A buyer read back from storage. */
    public static Buyer restore(BuyerId id, String name, PhoneNumber phone, Gender gender, LocalDate dateOfBirth,
                                EmailAddress email) {
        return new Buyer(id, name, phone, gender, dateOfBirth, email);
    }

    public BuyerId id() {
        return id;
    }

    public String name() {
        return name;
    }

    public PhoneNumber phone() {
        return phone;
    }

    public Gender gender() {
        return gender;
    }

    public LocalDate dateOfBirth() {
        return dateOfBirth;
    }

    public Optional<EmailAddress> email() {
        return Optional.ofNullable(email);
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Buyer that && id.equals(that.id);
    }

    @Override
    public int hashCode() {
        return id.hashCode();
    }

    @Override
    public String toString() {
        return "Buyer[" + id + ", " + name + "]";
    }
}
