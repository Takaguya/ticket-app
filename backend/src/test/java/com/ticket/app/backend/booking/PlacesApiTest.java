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
 * Places open every day (temple parks, water parks...): an admission business publishes one,
 * buyers pick a visit day, each ticket type may have a daily limit, and a ticket is good on its
 * day only. Every test makes its own businesses and place names, so the demo's places and the
 * other tests are never touched.
 */
class PlacesApiTest extends ApiTest {

    private static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));

    @Test
    void onlyAnAdmissionBusinessPublishesAPlaceAndItWaitsForApproval() {
        String owner = newPark("+85570001001", "Park Co One");

        post("/merchant/events/places", place("Lotus Park One", 5), owner)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Lotus Park One")
                .jsonPath("$.kind").isEqualTo("admission")
                .jsonPath("$.approved").isEqualTo(false)
                .jsonPath("$.venue").isEqualTo("Lotus Park")
                .jsonPath("$.ticketTypes[0].name").isEqualTo("Adult")
                .jsonPath("$.ticketTypes[0].priceCents").isEqualTo(1000)
                .jsonPath("$.ticketTypes[0].quantity").isEqualTo(5)
                .jsonPath("$.ticketTypes[1].name").isEqualTo("Child")
                .jsonPath("$.ticketTypes[1].quantity").isEqualTo(100000);

        // Another kind of business cannot publish a place, and a park cannot publish an event.
        post("/merchant/events/places", place("Sneaky Park", 5), accessTokenFor(OWNER))
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Only admission businesses publish places.");
        post("/merchant/events", Map.of("name", "A Marathon", "kind", "marathon", "startsAt", TODAY.plusDays(9) + "T06:00:00",
                "venue", "Riverside", "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 5))),
                owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("An admission business publishes places, not events.");
        post("/merchant/events", Map.of("name", "Sneaky Place", "kind", "admission",
                "startsAt", TODAY.plusDays(9) + "T06:00:00", "venue", "Riverside",
                "ticketTypes", List.of(Map.of("name", "Adult", "priceCents", 1000, "quantity", 5))),
                accessTokenFor(OWNER)).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Publish places with the place form.");
    }

    @Test
    void aPlaceNeedsANameATicketTypeAndSensibleLimits() {
        String owner = newPark("+85570001002", "Park Co Two");

        post("/merchant/events/places", Map.of("name", "Ab", "venue", "Somewhere", "ticketTypes",
                List.of(Map.of("name", "Adult", "priceCents", 100))), owner)
                .expectStatus().isBadRequest();
        post("/merchant/events/places", Map.of("name", "No Tickets Park", "venue", "Somewhere", "ticketTypes", List.of()), owner)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Add at least one ticket type.");
        post("/merchant/events/places", place("Zero Limit Park", 0), owner)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("A daily limit is at least 1. Leave it empty for no limit.");
        post("/merchant/events/places", Map.of("name", "Free Entry Park", "venue", "Somewhere", "ticketTypes",
                List.of(Map.of("name", "Adult"))), owner)
                .expectStatus().isBadRequest();
        // A limit equal to the "no limit" number would silently mean no limit.
        post("/merchant/events/places", place("Huge Limit Park", 100000), owner)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message")
                .isEqualTo("A daily limit is at most 99999. Leave it empty for no limit.");
        // A missing ticket type in the list is a mistake to explain, not a server error.
        java.util.List<Object> withHole = new java.util.ArrayList<>();
        withHole.add(null);
        post("/merchant/events/places", Map.of("name", "Hole Park", "venue", "Somewhere", "ticketTypes", withHole),
                owner).expectStatus().isBadRequest();
        post("/merchant/events/places", Map.of("name", "Free Park", "venue", "Somewhere", "ticketTypes",
                List.of(Map.of("name", "Adult", "priceCents", 0))), owner)
                .expectStatus().isCreated();
    }

    @Test
    void buyersSeeAPlaceOnlyOnceApprovedAndNeverAmongTheEvents() {
        String owner = newPark("+85570001003", "Park Co Three");
        String place = publish(owner, "Lotus Park Three", 5);
        String buyer = registerBuyer("+85570001013", "Rida Seng", "female");

        assertThat(ids(get("/catalog/places", buyer))).doesNotContain(place);
        get("/catalog/places/" + place, buyer).expectStatus().isNotFound();
        post("/buyer/bookings", Map.of("eventId", place, "lines", List.of(Map.of("ticketType", "Adult", "quantity", 1)),
                "payment", "card", "visitDate", TODAY.toString()), buyer).expectStatus().isEqualTo(409);

        approveEvent(place);
        assertThat(ids(get("/catalog/places", buyer))).contains(place);
        assertThat(ids(get("/catalog/events", buyer))).doesNotContain(place);
        get("/catalog/events/" + place, buyer).expectStatus().isOk();
        get("/catalog/places/" + place, buyer).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Lotus Park Three")
                .jsonPath("$.venue").isEqualTo("Lotus Park")
                .jsonPath("$.venueDetail").isEqualTo("Lotus Road, Phnom Penh")
                .jsonPath("$.about").isEqualTo("A test park.")
                .jsonPath("$.policy").isEqualTo("Refundable up to the day before")
                .jsonPath("$.organiser").isEqualTo("Park Co Three")
                .jsonPath("$.ticketTypes[0].name").isEqualTo("Adult")
                .jsonPath("$.ticketTypes[0].description").isEqualTo("Above 140cm")
                .jsonPath("$.ticketTypes[0].priceCents").isEqualTo(1000)
                .jsonPath("$.ticketTypes[0].dailyLimit").isEqualTo(5)
                .jsonPath("$.ticketTypes[1].name").isEqualTo("Child")
                .jsonPath("$.ticketTypes[1].dailyLimit").isEmpty();
        // A merchant cannot use the buyer catalogue.
        get("/catalog/places", owner).expectStatus().isForbidden();
    }

    @Test
    void theVisitDayIsCheckedAndTheDailyLimitCountsEachDayAlone() {
        String owner = newPark("+85570001004", "Park Co Four");
        String place = publishApproved(owner, "Lotus Park Four", 5);
        String sokha = registerBuyer("+85570001014", "Vuthy Ly", "male");
        String dara = registerBuyer("+85570001015", "Neary Pov", "female");
        LocalDate friday = TODAY.plusDays(3);
        LocalDate saturday = TODAY.plusDays(4);

        // The day: required, from today, up to 62 days.
        post("/buyer/bookings", order(place, "Adult", 1, null), sokha).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose the day you are visiting.");
        post("/buyer/bookings", order(place, "Adult", 1, TODAY.minusDays(1)), sokha).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose today or a later day.");
        post("/buyer/bookings", order(place, "Adult", 1, TODAY.plusDays(62)), sokha).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Tickets can be booked up to 62 days ahead.");
        post("/buyer/bookings", order(place, "Adult", 1, TODAY.plusDays(61)), sokha).expectStatus().isCreated();
        post("/buyer/bookings", order(place, "Senior", 1, friday), sokha).expectStatus().isBadRequest();
        post("/buyer/bookings", order(place, "Adult", 9, friday), sokha).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Maximum 8 tickets per booking.");

        get("/catalog/places/" + place + "/availability?date=" + TODAY.minusDays(1), sokha)
                .expectStatus().isBadRequest();
        get("/catalog/places/" + place + "/availability?date=soon", sokha).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Write the day like 2026-11-28.");

        // Adult has 5 a day, Child has no limit.
        get("/catalog/places/" + place + "/availability?date=" + friday, sokha).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.date").isEqualTo(friday.toString())
                .jsonPath("$.ticketTypes[0].name").isEqualTo("Adult")
                .jsonPath("$.ticketTypes[0].left").isEqualTo(5)
                .jsonPath("$.ticketTypes[1].name").isEqualTo("Child")
                .jsonPath("$.ticketTypes[1].left").isEmpty();

        post("/buyer/bookings", order(place, "Adult", 3, friday), sokha)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.visitDate").isEqualTo(friday.toString())
                .jsonPath("$.totalCents").isEqualTo(3000)
                .jsonPath("$.event.kind").isEqualTo("admission")
                .jsonPath("$.event.name").isEqualTo("Lotus Park Four")
                .jsonPath("$.lines[0].ticketType").isEqualTo("Adult")
                .jsonPath("$.lines[0].quantity").isEqualTo(3)
                .jsonPath("$.seats.length()").isEqualTo(0);
        availabilityIs(sokha, place, friday, 2);
        post("/buyer/bookings", order(place, "Adult", 3, friday), dara).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Only 2 left for Adult.");
        post("/buyer/bookings", order(place, "Adult", 2, friday), dara).expectStatus().isCreated();
        post("/buyer/bookings", order(place, "Adult", 1, friday), sokha).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Adult is sold out.");
        availabilityIs(sokha, place, friday, 0);

        // Another day is its own: Saturday is untouched, and the unlimited ticket sells on.
        availabilityIs(sokha, place, saturday, 5);
        post("/buyer/bookings", order(place, "Adult", 4, saturday), sokha).expectStatus().isCreated();
        post("/buyer/bookings", order(place, "Child", 8, friday), sokha).expectStatus().isCreated();
        post("/buyer/bookings", order(place, "Child", 8, friday), dara).expectStatus().isCreated();
    }

    @Test
    void theOwnerSeesVisitDaysCancellingFreesTheDayAndDoorSalesAreForToday() {
        String owner = newPark("+85570001005", "Park Co Five");
        String place = publishApproved(owner, "Lotus Park Five", 5);
        String buyer = registerBuyer("+85570001016", "Visal Oum", "male");
        LocalDate tomorrow = TODAY.plusDays(1);

        String booking = read(post("/buyer/bookings", order(place, "Adult", 4, tomorrow), buyer)
                .expectStatus().isCreated().expectBody(), "$.id");
        post("/buyer/bookings", order(place, "Adult", 1, TODAY), buyer).expectStatus().isCreated();

        String all = json(get("/merchant/bookings", owner));
        assertThat(JsonPath.<List<String>>read(all, "$[?(@.id == '" + booking + "')].visitDate"))
                .containsExactly(tomorrow.toString());

        // A door sale is for today: today's limit is counted without tomorrow's booking.
        post("/merchant/events/" + place + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "Adult", "quantity", 4)),
                "buyerPhone", "+85512000555", "payment", "cash"), owner)
                .expectStatus().isCreated()
                .expectBody().jsonPath("$.visitDate").isEqualTo(TODAY.toString());
        post("/merchant/events/" + place + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "Adult", "quantity", 1)),
                "buyerPhone", "+85512000555", "payment", "cash"), owner)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Adult is sold out.");

        // The numbers are today's visits: 4 + 1 adults today, tomorrow's 4 are not counted.
        get("/merchant/events/" + place + "/summary", owner).expectStatus().isOk()
                .expectBody().jsonPath("$.sold").isEqualTo(5).jsonPath("$.checkedIn").isEqualTo(0);

        // Cancelling tomorrow's booking frees tomorrow's tickets and refunds the buyer.
        availabilityIs(buyer, place, tomorrow, 1);
        post("/merchant/bookings/" + booking + "/cancel", Map.of("reason", "eventChanged"), owner)
                .expectStatus().isOk()
                .expectBody().jsonPath("$.status").isEqualTo("cancelled");
        availabilityIs(buyer, place, tomorrow, 5);
        get("/buyer/bookings/" + booking, buyer).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("cancelled")
                .jsonPath("$.visitDate").isEqualTo(tomorrow.toString())
                .jsonPath("$.cancellation.refundCents").isEqualTo(4000);
    }

    @Test
    void aTicketOpensOnlyOnItsVisitDay() {
        String owner = newPark("+85570001006", "Park Co Six");
        String place = publishApproved(owner, "Lotus Park Six", 50);
        String buyer = registerBuyer("+85570001017", "Dara Heng", "male");

        String later = read(post("/buyer/bookings", order(place, "Adult", 1, TODAY.plusDays(2)), buyer)
                .expectStatus().isCreated().expectBody(), "$.id");
        String today = read(post("/buyer/bookings", order(place, "Adult", 2, TODAY), buyer)
                .expectStatus().isCreated().expectBody(), "$.id");

        // A place is open today, so there is no event day to wait for: the ticket's own day decides.
        post("/merchant/checkins", Map.of("eventId", place, "code", later), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").value(String.class, message -> assertThat(message)
                        .isEqualTo("This ticket is for " + TODAY.plusDays(2).format(
                                java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy", java.util.Locale.ENGLISH))
                                + ". Check-in opens on that day."));
        post("/merchant/checkins", Map.of("eventId", place, "code", today), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("admitted");
        post("/merchant/checkins", Map.of("eventId", place, "code", today), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("alreadyUsed");

        // A cancelled ticket for another day is answered "cancelled", not "opens on that day".
        post("/merchant/bookings/" + later + "/cancel", Map.of("reason", "other"), owner).expectStatus().isOk();
        post("/merchant/checkins", Map.of("eventId", place, "code", later), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("cancelled");

        get("/merchant/events/" + place + "/summary", owner).expectStatus().isOk()
                .expectBody().jsonPath("$.sold").isEqualTo(2).jsonPath("$.checkedIn").isEqualTo(2);
        post("/merchant/bookings/" + today + "/cancel", Map.of("reason", "other"), owner)
                .expectStatus().isEqualTo(409);
    }

    @Test
    void aBusinessesPlacesShareOneGateButAnotherBusinessesTicketsAreRefused() {
        String owner = newPark("+85570001008", "Park Co Eight");
        String first = publishApproved(owner, "Lotus Park Eight A", 50);
        String second = publishApproved(owner, "Lotus Park Eight B", 50);
        String stranger = newPark("+85570001009", "Park Co Nine");
        String strangersPlace = publishApproved(stranger, "Lotus Park Nine", 50);
        String buyer = registerBuyer("+85570001018", "Sreyneang Lim", "female");

        String atSecond = read(post("/buyer/bookings", order(second, "Adult", 1, TODAY), buyer)
                .expectStatus().isCreated().expectBody(), "$.id");
        String atStranger = read(post("/buyer/bookings", order(strangersPlace, "Adult", 1, TODAY), buyer)
                .expectStatus().isCreated().expectBody(), "$.id");

        // Scanning at the first place admits a ticket for the second place of the same business.
        post("/merchant/checkins", Map.of("eventId", first, "code", atSecond), owner).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.result").isEqualTo("admitted")
                .jsonPath("$.booking.eventId").isEqualTo(second);
        get("/merchant/events/" + second + "/summary", owner).expectStatus().isOk()
                .expectBody().jsonPath("$.checkedIn").isEqualTo(1);
        // Another business's ticket is never admitted.
        post("/merchant/checkins", Map.of("eventId", first, "code", atStranger), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("otherEvent");
    }

    @Test
    void theAdminSeesAPlaceAsLiveOnceApprovedAndNeverEnded() {
        String owner = newPark("+85570001007", "Park Co Seven");
        String place = publish(owner, "Lotus Park Seven", 5);
        String admin = adminToken();

        assertThat(statusOf(admin, "Lotus Park Seven")).isEqualTo("awaitingApproval");
        approveEvent(place);
        assertThat(statusOf(admin, "Lotus Park Seven")).isEqualTo("live");
        assertThat(JsonPath.<List<String>>read(json(get("/admin/events", admin)),
                "$[?(@.name == 'Lotus Park Seven')].kind")).containsExactly("admission");
    }

    private String newPark(String phone, String name) {
        String owner = registerBusiness(phone, name, "admission");
        approveBusinessOf(owner);
        return owner;
    }

    private String publish(String owner, String name, int adultsPerDay) {
        return read(post("/merchant/events/places", place(name, adultsPerDay), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
    }

    private String publishApproved(String owner, String name, int adultsPerDay) {
        String id = publish(owner, name, adultsPerDay);
        approveEvent(id);
        return id;
    }

    /** Adult $10 with a daily limit, Child $6 with none. */
    private static Map<String, Object> place(String name, int adultsPerDay) {
        return Map.of("name", name, "venue", "Lotus Park", "venueDetail", "Lotus Road, Phnom Penh",
                "about", "A test park.", "policy", "Refundable up to the day before",
                "ticketTypes", List.of(
                        Map.of("name", "Adult", "description", "Above 140cm", "priceCents", 1000,
                                "dailyLimit", adultsPerDay),
                        Map.of("name", "Child", "description", "Under 140cm", "priceCents", 600)));
    }

    private static Map<String, Object> order(String place, String ticketType, int quantity, LocalDate visit) {
        Map<String, Object> order = new java.util.HashMap<>(Map.of("eventId", place,
                "lines", List.of(Map.of("ticketType", ticketType, "quantity", quantity)), "payment", "card"));
        if (visit != null) {
            order.put("visitDate", visit.toString());
        }
        return order;
    }

    private void availabilityIs(String buyer, String place, LocalDate day, int adultsLeft) {
        get("/catalog/places/" + place + "/availability?date=" + day, buyer).expectStatus().isOk()
                .expectBody().jsonPath("$.ticketTypes[0].left").isEqualTo(adultsLeft);
    }

    private String statusOf(String admin, String name) {
        List<String> found = JsonPath.read(json(get("/admin/events", admin)),
                "$[?(@.name == '" + name + "')].status");
        return found.getFirst();
    }

    private List<String> ids(ResponseSpec response) {
        return JsonPath.read(json(response), "$[*].id");
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectStatus().isOk().expectBody().returnResult().getResponseBody(),
                StandardCharsets.UTF_8);
    }
}
