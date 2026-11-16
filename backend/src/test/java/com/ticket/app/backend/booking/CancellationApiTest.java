package com.ticket.app.backend.booking;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import com.jayway.jsonpath.JsonPath;
import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * The owner cancelling bookings from the merchant app: who may, which bookings, and
 * what it changes. Uses a business of its own, so the demo's numbers stay as other
 * tests expect them. Refunds of online bookings are not covered by an API test yet.
 */
class CancellationApiTest extends ApiTest {

    private static final String NIGHT_RUN = "30000000-0000-7000-8000-000000000003";
    private static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));

    @Test
    void theOwnerCancelsADoorSaleWithAReasonOnce() {
        String owner = newBusiness("+85511900101", "Cancel Test Club");
        String event = publishAndApprove(owner, "Cancel Test Run", TODAY.plusDays(3));
        String bookingId = sellTwoAtTheDoor(owner, event);
        long soldBefore = sold(owner, event);

        post(cancelPath(bookingId), Map.of("reason", "buyerAsked"), owner).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.id").isEqualTo(bookingId)
                .jsonPath("$.status").isEqualTo("cancelled")
                .jsonPath("$.cancellation.reason").isEqualTo("buyerAsked")
                .jsonPath("$.cancellation.staffName").isEqualTo("Test Owner")
                .jsonPath("$.cancellation.at").exists()
                // A door sale is paid back by the business, not by Pin.
                .jsonPath("$.cancellation.refundCents").isEqualTo(0);
        assertThat(sold(owner, event)).isEqualTo(soldBefore - 2);

        // Sent again, with another reason: answered as it is.
        post(cancelPath(bookingId), Map.of("reason", "other"), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.cancellation.reason").isEqualTo("buyerAsked");
        assertThat(sold(owner, event)).isEqualTo(soldBefore - 2);

        String listed = json(get("/merchant/bookings", owner));
        assertThat(JsonPath.<List<String>>read(listed, "$[?(@.id == '" + bookingId + "')].cancellation.reason"))
                .containsExactly("buyerAsked");
    }

    @Test
    void aReasonIsNeededAndOnlyOwnersCancelTheirOwnBookings() {
        String owner = newBusiness("+85511900102", "Cancel Rules Club");
        String event = publishAndApprove(owner, "Cancel Rules Run", TODAY.plusDays(3));
        String bookingId = sellTwoAtTheDoor(owner, event);

        post(cancelPath(bookingId), Map.of("reason", "bored"), owner).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose why the booking is cancelled.");
        post(cancelPath(bookingId), Map.of(), owner).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose why the booking is cancelled.");

        // A scanner of another business, and the owner of another business.
        post(cancelPath(bookingId), Map.of("reason", "buyerAsked"), accessTokenFor(SECOND_SCANNER))
                .expectStatus().isForbidden();
        post(cancelPath(bookingId), Map.of("reason", "buyerAsked"), accessTokenFor(OWNER))
                .expectStatus().isNotFound();
        post(cancelPath("TK00000000"), Map.of("reason", "buyerAsked"), owner).expectStatus().isNotFound();
        post(cancelPath("not-a-booking"), Map.of("reason", "buyerAsked"), owner).expectStatus().isNotFound();

        get("/merchant/bookings", owner).expectStatus().isOk()
                .expectBody().jsonPath("$[0].status").isEqualTo("open");
    }

    @Test
    void checkedInBookingsAndEndedEventsCannotBeCancelledAndCancelledTicketsDoNotScan() {
        String owner = newBusiness("+85511900103", "Cancel Door Club");
        String today = publishAndApprove(owner, "Cancel Tonight Run", TODAY);
        String admitted = sellTwoAtTheDoor(owner, today);
        String cancelled = sellTwoAtTheDoor(owner, today);

        post("/merchant/checkins", Map.of("eventId", today, "code", admitted), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("admitted");
        post(cancelPath(admitted), Map.of("reason", "soldByMistake"), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("This booking is checked in, so it can't be cancelled.");

        post(cancelPath(cancelled), Map.of("reason", "eventChanged"), owner).expectStatus().isOk();
        post("/merchant/checkins", Map.of("eventId", today, "code", cancelled), owner).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("cancelled")
                .jsonPath("$.booking.cancellation.reason").isEqualTo("eventChanged");

        // The demo's run three weeks ago.
        String ended = JsonPath.read(json(get("/merchant/events/" + NIGHT_RUN + "/bookings?status=open",
                accessTokenFor(OWNER))), "$[0].id");
        post(cancelPath(ended), Map.of("reason", "buyerAsked"), accessTokenFor(OWNER)).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("The event has ended.");
    }

    /** A new, approved business; returns its owner's access token. */
    private String newBusiness(String phone, String name) {
        String owner = registerBusiness(phone, name);
        approveBusinessOf(owner);
        return owner;
    }

    private String publishAndApprove(String owner, String name, LocalDate day) {
        String id = read(post("/merchant/events", Map.of(
                "name", name,
                "startsAt", day + "T23:00:00",
                "venue", "Riverside",
                "kind", "marathon",
                "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 50))), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(id);
        return id;
    }

    private String sellTwoAtTheDoor(String owner, String event) {
        return read(post("/merchant/events/" + event + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "5K", "quantity", 2)),
                "buyerPhone", "+85512000111",
                "payment", "cash"), owner).expectStatus().isCreated().expectBody(), "$.id");
    }

    private long sold(String owner, String event) {
        return JsonPath.<Number>read(json(get("/merchant/events/" + event + "/summary", owner)), "$.sold")
                .longValue();
    }

    private static String cancelPath(String bookingId) {
        return "/merchant/bookings/" + bookingId + "/cancel";
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectStatus().isOk().expectBody().returnResult().getResponseBody(),
                StandardCharsets.UTF_8);
    }
}
