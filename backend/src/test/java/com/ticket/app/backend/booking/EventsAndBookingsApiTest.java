package com.ticket.app.backend.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.jayway.jsonpath.JsonPath;
import com.ticket.app.backend.ApiTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * Events, bookings, check-in, door sales and the summary through the HTTP API,
 * against the demo business. Covers the handoff's acceptance scenarios that do not
 * need the user app: check-in by scan and by ID, double scan, cancelled, wrong event,
 * publishing an event, and roles.
 */
class EventsAndBookingsApiTest extends ApiTest {

    // The demo events, see DemoDataSeeder.
    private static final String MARATHON = "30000000-0000-7000-8000-000000000001";
    private static final String KAMPOT = "30000000-0000-7000-8000-000000000002";
    private static final String NIGHT_RUN = "30000000-0000-7000-8000-000000000003";

    private static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));

    @Test
    void theTeamSeesTheBusinessEvents() {
        get("/merchant/events", scanner()).expectStatus().isOk()
                .expectBody()
                .jsonPath("$[?(@.id == '" + MARATHON + "')].name").isEqualTo(List.of("Phnom Penh Half Marathon 2026"));

        get("/merchant/events/" + MARATHON, scanner()).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.capacity").isEqualTo(220)
                .jsonPath("$.commissionRate").isEqualTo(5.0)
                .jsonPath("$.startsAt").value(String.class, startsAt -> assertThat(startsAt).startsWith(TODAY + "T05:30"))
                .jsonPath("$.ticketTypes[1].name").isEqualTo("10K")
                .jsonPath("$.ticketTypes[1].priceCents").isEqualTo(1800)
                .jsonPath("$.ticketTypes[1].quantity").isEqualTo(80);
    }

    @Test
    void theWholeBusinessBookingsComeInOneList() {
        String all = json(get("/merchant/bookings", scanner()).expectStatus().isOk());
        List<String> eventIds = JsonPath.read(all, "$[*].eventId");

        assertThat(eventIds).contains(MARATHON, KAMPOT, NIGHT_RUN);
        assertThat(eventIds.size()).isGreaterThanOrEqualTo(64 + 110 + 90);
    }

    @Test
    void onlyTheOwnerPublishesEventsAndThePublishingRulesApply() {
        Map<String, Object> templeRun = event("Siem Reap Temple Run", TODAY.plusDays(16),
                List.of(ticketType("10K", 1500, 150), ticketType("5K", 0, 100)));

        post("/merchant/events", templeRun, scanner()).expectStatus().isEqualTo(403)
                .expectBody().jsonPath("$.code").isEqualTo("forbidden");

        post("/merchant/events", event("Yesterday Run", TODAY.minusDays(1), List.of(ticketType("5K", 1000, 10))),
                owner())
                .expectStatus().isBadRequest()
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("The event date cannot be in the past.");

        List<Map<String, Object>> seven = new ArrayList<>();
        for (int i = 1; i <= 7; i++) {
            seven.add(ticketType("Type " + i, 1000, 10));
        }
        post("/merchant/events", event("Too Many Types Run", TODAY.plusDays(3), seven), owner())
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("An event can have at most 6 ticket types.");

        String id = read(post("/merchant/events", templeRun, owner()).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.capacity").isEqualTo(250)
                .jsonPath("$.commissionRate").isEqualTo(5.0)
                .jsonPath("$.ticketTypes[1].priceCents").isEqualTo(0), "$.id");
        get("/merchant/events/" + id, scanner()).expectStatus().isOk()
                .expectBody().jsonPath("$.name").isEqualTo("Siem Reap Temple Run");
    }

    @Test
    void aScanAdmitsAValidBookingOnceThenReportsItUsed() {
        String id = firstBookingId(MARATHON, "open");

        // Typing the 8 digits is enough.
        checkIn(MARATHON, id.substring(2)).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("admitted")
                .jsonPath("$.booking.id").isEqualTo(id)
                .jsonPath("$.booking.status").isEqualTo("checkedIn")
                .jsonPath("$.booking.checkIn.staffName").isEqualTo("Sreyneang Lim");

        checkIn(MARATHON, id).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("alreadyUsed")
                .jsonPath("$.booking.checkIn.staffName").isEqualTo("Sreyneang Lim");
    }

    @Test
    void scansThatMustNotAdmit() {
        checkIn(MARATHON, firstBookingId(MARATHON, "cancelled")).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("cancelled");

        checkIn(MARATHON, firstBookingId(KAMPOT, "open")).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("otherEvent")
                .jsonPath("$.eventName").isEqualTo("Kampot River Run 2026")
                .jsonPath("$.buyerName").exists();

        checkIn(MARATHON, "TK00000000").expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("notFound")
                .jsonPath("$.bookingId").isEqualTo("TK00000000");

        checkIn(KAMPOT, firstBookingId(KAMPOT, "open")).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Check-in opens on the day of the event.");

        checkIn(NIGHT_RUN, firstBookingId(NIGHT_RUN, "open")).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("The event has ended.");
    }

    @Test
    void theOwnerSellsAtTheDoorWithinWhatIsLeft() {
        String before = json(get(summaryPath(MARATHON), owner()).expectStatus().isOk());
        Map<String, Object> twoTenK = doorSale(List.of(Map.of("ticketType", "10K", "quantity", 2)), "cash");

        post(doorSalesPath(MARATHON), twoTenK, scanner()).expectStatus().isEqualTo(403);

        post(doorSalesPath(MARATHON), twoTenK, owner()).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.id").value(String.class, id -> assertThat(id).matches("TK[0-9]{8}"))
                .jsonPath("$.buyerName").isEqualTo("Walk-in guest")
                .jsonPath("$.channel").isEqualTo("door")
                .jsonPath("$.status").isEqualTo("open")
                .jsonPath("$.payment").isEqualTo("cash")
                .jsonPath("$.totalCents").isEqualTo(3600);

        String after = json(get(summaryPath(MARATHON), owner()).expectStatus().isOk());
        assertThat(number(after, "$.sold")).isEqualTo(number(before, "$.sold") + 2);
        assertThat(number(after, "$.doorCents")).isEqualTo(number(before, "$.doorCents") + 3600);
        assertThat(number(after, "$.commissionCents")).isEqualTo(number(before, "$.commissionCents"));

        post(doorSalesPath(MARATHON), doorSale(List.of(Map.of("ticketType", "10K", "quantity", 9)), "cash"),
                owner())
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Maximum 8 tickets per sale.");

        post(doorSalesPath(MARATHON), doorSale(List.of(Map.of("ticketType", "10K", "quantity", 1)), "card"),
                owner())
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Door sales are paid by cash or KHQR.");
    }

    @Test
    void aDoorSaleCannotSellMoreThanIsLeft() {
        String smallRun = read(post("/merchant/events",
                event("Small Door Run", TODAY.plusDays(2), List.of(ticketType("5K", 1000, 3))), owner())
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(smallRun);
        Map<String, Object> twoTickets = doorSale(List.of(Map.of("ticketType", "5K", "quantity", 2)), "cash");

        post(doorSalesPath(smallRun), twoTickets, owner()).expectStatus().isCreated();
        post(doorSalesPath(smallRun), twoTickets, owner()).expectStatus().isEqualTo(409)
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("Only 1 left.");
    }

    @Test
    void theSummaryAddsUpAndIsForTheOwner() {
        get(summaryPath(MARATHON), scanner()).expectStatus().isEqualTo(403);

        String summary = json(get(summaryPath(MARATHON), owner()).expectStatus().isOk());
        assertThat(number(summary, "$.capacity")).isEqualTo(220);
        assertThat(number(summary, "$.left")).isEqualTo(220 - number(summary, "$.sold"));
        assertThat(number(summary, "$.revenueCents"))
                .isEqualTo(number(summary, "$.onlineCents") + number(summary, "$.doorCents"));
        assertThat(number(summary, "$.netCents"))
                .isEqualTo(number(summary, "$.revenueCents") - number(summary, "$.commissionCents"));
        // 5% of online sales, rounded per booking.
        assertThat(number(summary, "$.commissionCents"))
                .isCloseTo(number(summary, "$.onlineCents") / 20, within(number(summary, "$.bookingCount")));
        assertThat(JsonPath.<List<Object>>read(summary, "$.byTicketType")).hasSize(3);
    }

    @Test
    void bookingsCanBeFoundByNameIdOrPhone() {
        String all = json(get(bookingsPath(MARATHON, ""), scanner()).expectStatus().isOk());
        String id = JsonPath.read(all, "$[0].id");
        String firstName = JsonPath.<String>read(all, "$[0].buyerName").split(" ")[0].toLowerCase(Locale.ROOT);
        String phone = JsonPath.read(all, "$[0].phone");
        String localDigits = "0" + phone.substring(4, 8);

        assertThat(ids(bookingsPath(MARATHON, "?q=" + id.substring(2)))).containsExactly(id);
        assertThat(ids(bookingsPath(MARATHON, "?q=" + firstName))).contains(id);
        assertThat(ids(bookingsPath(MARATHON, "?q=" + localDigits))).contains(id);

        String cancelled = json(get(bookingsPath(MARATHON, "?status=cancelled"), scanner()).expectStatus().isOk());
        assertThat(JsonPath.<List<String>>read(cancelled, "$[*].status")).isNotEmpty().containsOnly("cancelled");
    }

    @Test
    void theOwnerDownloadsTheBookingsAsCsv() {
        String path = "/merchant/events/" + MARATHON + "/bookings.csv?status=checkedIn";
        get(path, scanner()).expectStatus().isEqualTo(403);

        get(path, owner()).expectStatus().isOk()
                .expectHeader().value(HttpHeaders.CONTENT_TYPE, type -> assertThat(type).startsWith("text/csv"))
                .expectHeader().value(HttpHeaders.CONTENT_DISPOSITION, disposition -> assertThat(disposition)
                        .contains("phnom-penh-half-marathon-2026-bookings-checked-in.csv"))
                .expectBody(String.class).value(csv -> assertThat(csv)
                        .startsWith("﻿\"Booking ID\",\"Name\",\"Phone\"")
                        .contains("\"Checked in\"")
                        .doesNotContain("\"Not checked in\""));
    }

    @Test
    void anotherBusinessCannotSeeOrScanTheseEvents() {
        String stranger = registerBusiness("+85570000100", "Battambang Bamboo Train");

        get("/merchant/events", stranger).expectStatus().isOk()
                .expectBody().jsonPath("$.length()").isEqualTo(0);
        get("/merchant/events/" + MARATHON, stranger).expectStatus().isEqualTo(404)
                .expectBody().jsonPath("$.code").isEqualTo("not_found");
        get(bookingsPath(MARATHON, ""), stranger).expectStatus().isEqualTo(404);
        post("/merchant/checkins", Map.of("eventId", MARATHON, "code", "TK00000000"), stranger)
                .expectStatus().isEqualTo(404);
    }

    // ------------------------------------------------------------------ helpers

    private String owner() {
        return accessTokenFor(OWNER);
    }

    private String scanner() {
        return accessTokenFor(SECOND_SCANNER);
    }

    private ResponseSpec checkIn(String eventId, String code) {
        return post("/merchant/checkins", Map.of("eventId", eventId, "code", code), scanner());
    }

    private String firstBookingId(String eventId, String status) {
        String bookings = json(get(bookingsPath(eventId, "?status=" + status), scanner()).expectStatus().isOk());
        return JsonPath.read(bookings, "$[0].id");
    }

    private List<String> ids(String path) {
        return JsonPath.read(json(get(path, scanner()).expectStatus().isOk()), "$[*].id");
    }

    private static String bookingsPath(String eventId, String query) {
        return "/merchant/events/" + eventId + "/bookings" + query;
    }

    private static String summaryPath(String eventId) {
        return "/merchant/events/" + eventId + "/summary";
    }

    private static String doorSalesPath(String eventId) {
        return "/merchant/events/" + eventId + "/door-sales";
    }

    private static Map<String, Object> event(String name, LocalDate day, List<Map<String, Object>> ticketTypes) {
        return Map.of("name", name, "startsAt", day + "T06:00:00", "venue", "Angkor Wat west gate",
                "kind", "marathon", "ticketTypes", ticketTypes);
    }

    private static Map<String, Object> ticketType(String name, long priceCents, int quantity) {
        return Map.of("name", name, "priceCents", priceCents, "quantity", quantity);
    }

    private static Map<String, Object> doorSale(List<Map<String, Object>> lines, String payment) {
        return Map.of("lines", lines, "buyerPhone", "+85512000111", "payment", payment);
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectBody().returnResult().getResponseBody(), StandardCharsets.UTF_8);
    }

    private static long number(String json, String path) {
        return JsonPath.<Number>read(json, path).longValue();
    }
}
