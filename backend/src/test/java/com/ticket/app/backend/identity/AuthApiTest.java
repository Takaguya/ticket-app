package com.ticket.app.backend.identity;

import java.util.Map;

import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.client.RestTestClient.BodyContentSpec;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/** Sign-in and account creation through the HTTP API. Each test uses its own numbers. */
class AuthApiTest extends ApiTest {

    @Test
    void theDemoOwnerIsSignedIn() {
        get("/me", accessTokenFor(OWNER)).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Vannak Sok")
                .jsonPath("$.phone").isEqualTo(OWNER)
                .jsonPath("$.role").isEqualTo("owner")
                .jsonPath("$.business.name").isEqualTo("Khmer Runners Club")
                .jsonPath("$.business.type").isEqualTo("events");
    }

    @Test
    void aKnownNumberGetsASessionAndSigningOutEndsIt() {
        sendCode(SCANNER);
        BodyContentSpec answer = verify(SCANNER, CODE).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.registrationToken").doesNotExist()
                .jsonPath("$.session.user.name").isEqualTo("Dara Keo")
                .jsonPath("$.session.user.phone").isEqualTo(SCANNER)
                .jsonPath("$.session.user.role").isEqualTo("scanner")
                .jsonPath("$.session.user.business.name").isEqualTo("Khmer Runners Club");
        String accessToken = read(answer, "$.session.accessToken");
        get("/me", accessToken).expectStatus().isOk();

        http.post().uri("/auth/sign-out").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .exchange()
                .expectStatus().isNoContent();

        get("/me", accessToken).expectStatus().isUnauthorized()
                .expectBody().jsonPath("$.code").isEqualTo("unauthorized");
    }

    @Test
    void aWrongCodeIsRefused() {
        sendCode("+85570000001");

        verify("+85570000001", "000000").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_code");
    }

    @Test
    void afterFiveWrongCodesEvenTheRightOneIsRefused() {
        sendCode("+85570000002");
        for (int i = 0; i < 5; i++) {
            verify("+85570000002", "000000").expectStatus().isBadRequest();
        }

        verify("+85570000002", CODE).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_code");
    }

    @Test
    void aCodeWorksOnlyOnce() {
        sendCode("+85570000003");
        verify("+85570000003", CODE).expectStatus().isOk();

        verify("+85570000003", CODE).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_code");
    }

    @Test
    void aCodeCannotBeVerifiedBeforeOneWasSent() {
        verify("+85570000009", CODE).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_code");
    }

    @Test
    void askingForAnotherCodeWithin30SecondsIsRefused() {
        sendCode("+85570000004");

        post("/auth/otp", Map.of("phone", "+85570000004", "purpose", "login"))
                .expectStatus().isEqualTo(429)
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("Please wait a moment before asking for another code.");
    }

    @Test
    void aNewNumberRegistersABusinessAndBecomesItsOwner() {
        String registrationToken = registrationTokenFor("+85570000005");

        BodyContentSpec answer = submitBusinessForm(registrationToken).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.user.role").isEqualTo("owner")
                .jsonPath("$.user.name").isEqualTo("Sophea Lim")
                .jsonPath("$.user.phone").isEqualTo("+85570000005")
                .jsonPath("$.user.business.name").isEqualTo("Kampot Night Market")
                .jsonPath("$.user.business.type").isEqualTo("admission");
        get("/me", read(answer, "$.accessToken")).expectStatus().isOk();

        // The registration token works only once.
        submitBusinessForm(registrationToken).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_registration");
    }

    @Test
    void aNewNumberJoinsTheTeamWithTheJoinCode() {
        String registrationToken = registrationTokenFor("+85570000006");

        // A wrong code is refused, and the token still works for another try.
        joinTeam(registrationToken, "999 999").expectStatus().isBadRequest()
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("That join code is not right. Ask the owner for the current code.");

        joinTeam(registrationToken, "482 913").expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.accessToken").exists()
                .jsonPath("$.user.role").isEqualTo("scanner")
                .jsonPath("$.user.name").isEqualTo("Rithy Heng")
                .jsonPath("$.user.business.name").isEqualTo("Khmer Runners Club");
    }

    @Test
    void joinCodesCannotBeGuessed() {
        String registrationToken = registrationTokenFor("+85570000007");
        for (int i = 0; i < 4; i++) {
            joinTeam(registrationToken, "999 999").expectStatus().isBadRequest()
                    .expectBody().jsonPath("$.code").isEqualTo("rejected");
        }

        // The fifth wrong code uses the token up; even the right code then needs a new one.
        joinTeam(registrationToken, "999 999").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_registration");
        joinTeam(registrationToken, "482 913").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("invalid_registration");
    }

    @Test
    void requestsWithoutAValidSessionAreRefused() {
        http.get().uri("/me").exchange()
                .expectStatus().isUnauthorized()
                .expectBody().jsonPath("$.code").isEqualTo("unauthorized");

        get("/me", "not-a-real-token").expectStatus().isUnauthorized();
    }

    @Test
    void anInvalidPhoneNumberIsRefusedWithAMessageForThePerson() {
        post("/auth/otp", Map.of("phone", "12345", "purpose", "login"))
                .expectStatus().isBadRequest()
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("Enter a valid phone number.");
    }

    @Test
    void codesAreOnlySentToCambodianNumbers() {
        post("/auth/otp", Map.of("phone", "+14155550123", "purpose", "login"))
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter a valid phone number.");
    }

    /** Confirms a number that has no account and returns its registration token. */
    private String registrationTokenFor(String phone) {
        sendCode(phone);
        BodyContentSpec answer = verify(phone, CODE).expectStatus().isOk()
                .expectBody().jsonPath("$.session").doesNotExist();
        return read(answer, "$.registrationToken");
    }

    private ResponseSpec submitBusinessForm(String registrationToken) {
        return post("/merchant/businesses", Map.of(
                "registrationToken", registrationToken,
                "businessName", "Kampot Night Market",
                "contactName", "Sophea Lim",
                "type", "admission"));
    }

    private ResponseSpec joinTeam(String registrationToken, String joinCode) {
        return post("/merchant/staff/join", Map.of(
                "registrationToken", registrationToken,
                "name", "Rithy Heng",
                "joinCode", joinCode));
    }
}
