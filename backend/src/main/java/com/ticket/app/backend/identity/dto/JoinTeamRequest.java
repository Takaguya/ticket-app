package com.ticket.app.backend.identity.dto;

import jakarta.validation.constraints.NotBlank;

/** A new number joins a business's team as a scanner, with the owner's join code. */
public record JoinTeamRequest(
        @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
        String name,
        @NotBlank(message = "Enter the join code.") String joinCode) {
}
