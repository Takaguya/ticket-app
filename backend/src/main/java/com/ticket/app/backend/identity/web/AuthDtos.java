package com.ticket.app.backend.identity.web;

import java.time.LocalDate;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.identity.application.BuyerSignedIn;
import com.ticket.app.backend.identity.application.SignedIn;
import com.ticket.app.backend.identity.application.VerifyResult;
import com.ticket.app.backend.shared.domain.EmailAddress;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/**
 * JSON of the sign-in endpoints. The shapes match the merchant app's
 * AuthSessionModel and MerchantUserModel, and the user app's AuthSessionModel and
 * PinUserModel. Phone numbers and names are checked by the domain; here only that the
 * fields are there.
 */
final class AuthDtos {

    private AuthDtos() {
    }

    /** {@code purpose} is login or register; it only changes wording in the app. */
    record OtpRequest(
            @NotBlank(message = "Enter a valid phone number.") String phone,
            @Pattern(regexp = "login|register") String purpose) {
    }

    /** {@code app} is merchant or user. */
    record VerifyRequest(
            @NotBlank(message = "Enter a valid phone number.") String phone,
            @NotBlank(message = "Enter the 6-digit code.")
            @Pattern(regexp = "[0-9]{6}", message = "Enter the 6-digit code.") String code,
            @Pattern(regexp = "login|register") String purpose,
            @Pattern(regexp = "merchant|user") String app) {
    }

    record RegisterBusinessRequest(
            @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
            String businessName,
            String contactName,
            @NotBlank(message = "Choose what the business sells.") String type) {
    }

    record JoinTeamRequest(
            @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
            String name,
            @NotBlank(message = "Enter the join code.") String joinCode) {
    }

    /**
     * A new number registers as a buyer. {@code gender} is female, male or other;
     * {@code dateOfBirth} is written like {@code 1996-04-12}; {@code email} is optional.
     */
    record RegisterBuyerRequest(
            @NotBlank(message = "Please confirm your phone number again.") String registrationToken,
            String name,
            @NotBlank(message = "Choose your gender.") String gender,
            @NotNull(message = "Enter your date of birth.") LocalDate dateOfBirth,
            String email) {
    }

    /**
     * Exactly one field is present. {@code session} is a {@link SessionResponse} for the
     * merchant app and a {@link BuyerSessionResponse} for the user app: the same JSON
     * shape, {@code {accessToken, user}}, with the user of that app.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    record VerifyResponse(Object session, String registrationToken) {

        static VerifyResponse of(VerifyResult result) {
            return switch (result) {
                case SignedIn signedIn -> new VerifyResponse(SessionResponse.of(signedIn), null);
                case BuyerSignedIn signedIn -> new VerifyResponse(BuyerSessionResponse.of(signedIn), null);
                case VerifyResult.NewNumber newNumber ->
                        new VerifyResponse(null, newNumber.registrationToken().value());
            };
        }
    }

    record BuyerSessionResponse(String accessToken, BuyerResponse user) {

        static BuyerSessionResponse of(BuyerSignedIn signedIn) {
            return new BuyerSessionResponse(signedIn.accessToken().value(), BuyerResponse.of(signedIn.buyer()));
        }
    }

    /** {@code dateOfBirth} is written like {@code 1996-04-12}; {@code email} is null when none was given. */
    record BuyerResponse(String id, String name, String phone, String gender, LocalDate dateOfBirth, String email) {

        static BuyerResponse of(Buyer buyer) {
            return new BuyerResponse(buyer.id().toString(), buyer.name(), buyer.phone().value(),
                    buyer.gender().code(), buyer.dateOfBirth(), buyer.email().map(EmailAddress::value).orElse(null));
        }
    }

    record SessionResponse(String accessToken, UserResponse user) {

        static SessionResponse of(SignedIn signedIn) {
            return new SessionResponse(signedIn.accessToken().value(), UserResponse.of(signedIn.member()));
        }
    }

    record UserResponse(String id, String name, String phone, String role, BusinessResponse business) {

        static UserResponse of(StaffMember member) {
            return new UserResponse(member.id().toString(), member.name(), member.phone().value(),
                    member.role().code(), BusinessResponse.of(member.business()));
        }
    }

    /** {@code status}: pending (waiting for Pin's approval), active or suspended. */
    record BusinessResponse(String id, String name, String type, String status) {

        static BusinessResponse of(Business business) {
            return new BusinessResponse(business.id().toString(), business.name(), business.type().code(),
                    business.status().code());
        }
    }
}
