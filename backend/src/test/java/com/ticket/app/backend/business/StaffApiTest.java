package com.ticket.app.backend.business;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * The owner's Staff screen through the HTTP API. Changes are made on a business of
 * its own, so the demo business's join code stays 482 913 for the other tests.
 */
class StaffApiTest extends ApiTest {

    @Autowired
    JdbcClient jdbc;

    @Test
    void onlyTheOwnerSeesTheTeam() {
        get("/merchant/staff", accessTokenFor(SECOND_SCANNER)).expectStatus().isEqualTo(403);

        get("/merchant/staff", accessTokenFor(OWNER)).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.joinCode").isEqualTo("482913")
                .jsonPath("$.members[0].name").isEqualTo("Vannak Sok")
                .jsonPath("$.members[0].role").isEqualTo("owner")
                .jsonPath("$.members[?(@.name == 'Sreyneang Lim')].role").isEqualTo(List.of("scanner"));
    }

    @Test
    void aNewJoinCodeReplacesTheOldOne() {
        String owner = registerBusiness("+85570000200", "Kep Crab Market");
        String oldCode = joinCode(owner);

        String newCode = read(post("/merchant/staff/join-code", Map.of(), owner).expectStatus().isOk().expectBody(),
                "$.joinCode");
        assertThat(newCode).matches("[0-9]{6}").isNotEqualTo(oldCode);
        assertThat(joinCode(owner)).isEqualTo(newCode);

        join("+85570000201", oldCode).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.code").isEqualTo("rejected");
    }

    @Test
    void aRemovedScannerIsSignedOutAndTheOwnerCannotBeRemoved() {
        String owner = registerBusiness("+85570000210", "Kampot Pepper Farm");
        String scanner = read(join("+85570000211", joinCode(owner)).expectStatus().isCreated().expectBody(),
                "$.accessToken");
        get("/me", scanner).expectStatus().isOk();

        String team = json(get("/merchant/staff", owner).expectStatus().isOk());
        String ownerId = JsonPath.read(team, "$.members[0].id");
        String scannerId = JsonPath.<List<String>>read(team, "$.members[?(@.role == 'scanner')].id").getFirst();

        delete("/merchant/staff/" + ownerId, owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("The owner cannot be removed.");

        delete("/merchant/staff/" + scannerId, owner).expectStatus().isNoContent();
        get("/me", scanner).expectStatus().isUnauthorized();
        // Their sessions are gone, not just refused.
        assertThat(jdbc.sql("select count(*) from sessions where member_id = :id")
                .param("id", UUID.fromString(scannerId)).query(Long.class).single()).isZero();
        assertThat(JsonPath.<List<Object>>read(json(get("/merchant/staff", owner)), "$.members")).hasSize(1);

        // Someone from another business, or nobody at all, is not on this team.
        delete("/merchant/staff/20000000-0000-7000-8000-000000000002", owner).expectStatus().isEqualTo(404);
        delete("/merchant/staff/not-an-id", owner).expectStatus().isEqualTo(404);
    }

    private String joinCode(String ownerToken) {
        return read(get("/merchant/staff", ownerToken).expectStatus().isOk().expectBody(), "$.joinCode");
    }

    /** Confirms a new number and joins with the code. */
    private ResponseSpec join(String phone, String joinCode) {
        sendCode(phone);
        String registrationToken = read(verify(phone, CODE).expectStatus().isOk().expectBody(), "$.registrationToken");
        return post("/merchant/staff/join", Map.of(
                "registrationToken", registrationToken, "name", "New Scanner", "joinCode", joinCode));
    }

    private ResponseSpec delete(String path, String accessToken) {
        return http.delete().uri(path).header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken).exchange();
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectBody().returnResult().getResponseBody(), StandardCharsets.UTF_8);
    }
}
