package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.service.RunnerInput;
import com.ticket.app.backend.booking.model.Runner;

/**
 * The runner of a race booking, matching the user app's RunnerDetails. {@code gender} is female, male
 * or other; {@code shirtSize} is XS, S, M, L or XL; {@code email} is optional.
 */
public record RunnerJson(String name, String phone, String email, String gender, Integer age, String nationality,
                  String emergencyName, String emergencyPhone, String shirtSize) {

    public static RunnerJson of(Runner runner) {
        return runner == null ? null : new RunnerJson(runner.name(), runner.phone().value(),
                runner.email() == null ? null : runner.email().value(), runner.gender().code(), runner.age(),
                runner.nationality(), runner.emergencyName(), runner.emergencyPhone().value(),
                runner.shirtSize().code());
    }

    /** Not checked here: the sale checks it only when the event is a race. */
    public RunnerInput toInput() {
        return new RunnerInput(name, phone, email, gender, age, nationality, emergencyName, emergencyPhone,
                shirtSize);
    }
}
