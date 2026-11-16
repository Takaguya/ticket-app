package com.ticket.app.backend.booking;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * The server saved a check-in or a door sale but its answer never reached the app (it
 * crashed, or the connection dropped). The app sends the request again with the same
 * attempt ID; the server must answer with what it already did.
 */
class RetryAfterLostAnswerApiTest extends ApiTest {

    private static final String MARATHON = "30000000-0000-7000-8000-000000000001";

    @Test
    void aScanSentAgainAfterALostAnswerIsStillAdmitted() {
        String scanner = accessTokenFor(SECOND_SCANNER);
        String bookingId = JsonPath.read(json(get("/merchant/events/" + MARATHON + "/bookings?status=open", scanner)),
                "$[0].id");
        String attempt = UUID.randomUUID().toString();

        // First try: saved, but pretend its answer was lost.
        String first = json(checkIn(bookingId, attempt, scanner));
        assertThat(JsonPath.<String>read(first, "$.result")).isEqualTo("admitted");

        // The same scan sent again: still "admitted", with the first scan's time.
        String retry = json(checkIn(bookingId, attempt, scanner));
        assertThat(JsonPath.<String>read(retry, "$.result")).isEqualTo("admitted");
        assertThat(JsonPath.<String>read(retry, "$.booking.checkIn.at"))
                .isEqualTo(JsonPath.<String>read(first, "$.booking.checkIn.at"));

        // A new scan of the same ticket, or anyone else's, is a second scan.
        assertThat(result(checkIn(bookingId, UUID.randomUUID().toString(), scanner))).isEqualTo("alreadyUsed");
        assertThat(result(checkIn(bookingId, null, scanner))).isEqualTo("alreadyUsed");
        assertThat(result(checkIn(bookingId, attempt, accessTokenFor(OWNER)))).isEqualTo("alreadyUsed");
    }

    @Test
    void aDoorSaleSentAgainAfterALostAnswerIsRecordedOnce() {
        String owner = accessTokenFor(OWNER);
        long soldBefore = sold(owner);
        String attempt = UUID.randomUUID().toString();

        String first = JsonPath.read(json(sell(attempt, owner).expectStatus().isCreated()), "$.id");
        String retry = JsonPath.read(json(sell(attempt, owner).expectStatus().isCreated()), "$.id");

        assertThat(retry).isEqualTo(first);
        assertThat(sold(owner)).isEqualTo(soldBefore + 2);

        // A new sale is a new booking.
        String next = JsonPath.read(json(sell(UUID.randomUUID().toString(), owner).expectStatus().isCreated()), "$.id");
        assertThat(next).isNotEqualTo(first);
        assertThat(sold(owner)).isEqualTo(soldBefore + 4);
    }

    @Test
    void anAttemptIdThatIsNotAUuidIsRefused() {
        post("/merchant/checkins", Map.of("eventId", MARATHON, "code", "TK00000000", "attemptId", "not-a-uuid"),
                accessTokenFor(SECOND_SCANNER))
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The attempt ID is not valid.");
    }

    private ResponseSpec checkIn(String code, String attempt, String token) {
        Map<String, Object> body = attempt == null
                ? Map.of("eventId", MARATHON, "code", code)
                : Map.of("eventId", MARATHON, "code", code, "attemptId", attempt);
        return post("/merchant/checkins", body, token);
    }

    private ResponseSpec sell(String attempt, String token) {
        return post("/merchant/events/" + MARATHON + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "5K Fun run", "quantity", 2)),
                "buyerPhone", "+85512000444",
                "payment", "cash",
                "attemptId", attempt), token);
    }

    private long sold(String owner) {
        return JsonPath.<Number>read(json(get("/merchant/events/" + MARATHON + "/summary", owner)), "$.sold")
                .longValue();
    }

    private static String result(ResponseSpec response) {
        return JsonPath.read(json(response), "$.result");
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectBody().returnResult().getResponseBody(), StandardCharsets.UTF_8);
    }
}
