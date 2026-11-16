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
 * Bus trips, from a bus company publishing one to buyers choosing seats and the owner
 * cancelling: who may publish, what buyers can see, seats never sold twice, and cancelling
 * freeing seats. Every test makes its own bus company and its own route, so the demo's trips
 * and the other tests are never touched.
 */
class BusTripsApiTest extends ApiTest {

    private static final LocalDate DAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh")).plusDays(5);

    @Test
    void onlyABusCompanyPublishesTripsAndTheyWaitForApproval() {
        String bus = newBusCompany("+85570000801", "Test Bus Co");

        post("/merchant/events/bus-trips", trip("Kratie", "Stung Treng", "seater"), bus).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Kratie to Stung Treng")
                .jsonPath("$.kind").isEqualTo("bus")
                .jsonPath("$.approved").isEqualTo(false)
                .jsonPath("$.venue").isEqualTo("Test Terminal")
                .jsonPath("$.capacity").isEqualTo(40)
                .jsonPath("$.ticketTypes[0].name").isEqualTo("Seat")
                .jsonPath("$.ticketTypes[0].priceCents").isEqualTo(1500)
                .jsonPath("$.ticketTypes[0].quantity").isEqualTo(40)
                .jsonPath("$.bus.origin").isEqualTo("Kratie")
                .jsonPath("$.bus.destination").isEqualTo("Stung Treng")
                .jsonPath("$.bus.coachLabel").isEqualTo("Seater · 2+2")
                .jsonPath("$.bus.seats").isEqualTo(40);

        // An events business cannot publish a trip, and the two kinds do not mix.
        post("/merchant/events/bus-trips", trip("Kratie", "Stung Treng", "seater"), accessTokenFor(OWNER))
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Only bus companies publish bus trips.");
        post("/merchant/events", Map.of("name", "A Marathon", "startsAt", DAY + "T06:00:00", "venue", "Riverside",
                "kind", "marathon", "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 5))),
                bus).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("A bus company publishes bus trips, not events.");
        post("/merchant/events", Map.of("name", "Sneaky Trip", "startsAt", DAY + "T06:00:00", "venue", "Riverside",
                "kind", "bus", "ticketTypes", List.of(Map.of("name", "Seat", "priceCents", 1000, "quantity", 5))),
                accessTokenFor(OWNER)).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Publish bus trips with the bus trip form.");

        // The trip is in the company's events, with its bus details.
        get("/merchant/events", bus).expectStatus().isOk()
                .expectBody().jsonPath("$[0].bus.destination").isEqualTo("Stung Treng");
    }

    @Test
    void aTripNeedsARouteACoachAndAPrice() {
        String bus = newBusCompany("+85570000802", "Rules Bus Co");

        post("/merchant/events/bus-trips", trip("Kratie", "kratie", "seater"), bus).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message")
                .isEqualTo("The trip must go somewhere other than where it starts.");
        post("/merchant/events/bus-trips", trip("Kratie", "Stung Treng", "limo"), bus).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose the kind of coach.");
        post("/merchant/events/bus-trips", Map.of("origin", "Kratie", "destination", "Stung Treng",
                "startsAt", DAY + "T08:00:00", "durationMinutes", 5, "coachType", "vip", "priceCents", 1000,
                "boardingPoint", "Terminal"), bus).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The trip takes between 10 minutes and 24 hours.");
        post("/merchant/events/bus-trips", Map.of("origin", "Kratie", "destination", "Stung Treng",
                "startsAt", DAY + "T08:00:00", "durationMinutes", 120, "coachType", "vip"), bus)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter the price of a seat (0 for free).");
        post("/merchant/events/bus-trips", Map.of("origin", "Kratie", "destination", "Stung Treng",
                "startsAt", DAY.minusDays(30) + "T08:00:00", "durationMinutes", 120, "coachType", "vip",
                "priceCents", 1000, "boardingPoint", "Terminal"), bus).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The event date cannot be in the past.");

        // Sleepers and VIP coaches have fewer seats.
        post("/merchant/events/bus-trips", trip("Kratie", "Mondulkiri", "sleeper"), bus).expectStatus().isCreated()
                .expectBody().jsonPath("$.capacity").isEqualTo(16);
        post("/merchant/events/bus-trips", trip("Kratie", "Banlung", "vip"), bus).expectStatus().isCreated()
                .expectBody().jsonPath("$.capacity").isEqualTo(30);
    }

    @Test
    void buyersSeeATripOnlyOnceAdminApprovesItAndBookSeatsNeverTwice() {
        String bus = newBusCompany("+85570000803", "Seats Bus Co");
        String trip = publish(bus, "Pailin", "Koh Kong", "seater");
        String sokha = registerBuyer("+85570000813", "Rida Seng", "female");
        String dara = registerBuyer("+85570000814", "Vuthy Ly", "male");

        // Waiting for approval: not on offer.
        assertThat(routes(sokha)).doesNotContain("pailin-koh-kong");
        get(seatsPath(trip), sokha).expectStatus().isNotFound();
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1A"), "payment", "card"), sokha)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("This event is no longer on sale.");

        approveEvent(trip);
        assertThat(routes(sokha)).contains("pailin-koh-kong");
        String departures = json(get(departuresPath("Pailin", "Koh Kong"), sokha));
        assertThat(JsonPath.<List<Number>>read(departures, "$[?(@.id == '" + trip + "')].seatsLeft"))
                .containsExactly(40);
        assertThat(JsonPath.<List<String>>read(departures, "$[?(@.id == '" + trip + "')].operatorName"))
                .containsExactly("Seats Bus Co");
        assertThat(JsonPath.<List<String>>read(departures, "$[?(@.id == '" + trip + "')].operatorCode"))
                .containsExactly("SB");

        // Sokha takes 1A and 1B.
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1A", "1B"), "payment", "abaKhqr"), sokha)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.seats[0]").isEqualTo("1A")
                .jsonPath("$.seats[1]").isEqualTo("1B")
                .jsonPath("$.totalCents").isEqualTo(3000)
                .jsonPath("$.lines[0].ticketType").isEqualTo("Seat")
                .jsonPath("$.lines[0].quantity").isEqualTo(2)
                .jsonPath("$.event.kind").isEqualTo("bus")
                .jsonPath("$.event.bus.origin").isEqualTo("Pailin")
                .jsonPath("$.status").isEqualTo("open");

        // The map shows them taken by a woman; the rest are free; the aisle is empty.
        get(seatsPath(trip), dara).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.seatType").isEqualTo("Seater · 2+2")
                .jsonPath("$.priceCents").isEqualTo(1500)
                .jsonPath("$.rows.length()").isEqualTo(10)
                .jsonPath("$.rows[0][0].id").isEqualTo("1A")
                .jsonPath("$.rows[0][0].status").isEqualTo("takenByFemale")
                .jsonPath("$.rows[0][1].status").isEqualTo("takenByFemale")
                .jsonPath("$.rows[0][2]").isEmpty()
                .jsonPath("$.rows[0][3].id").isEqualTo("1C")
                .jsonPath("$.rows[0][3].status").isEqualTo("available");
        assertThat(JsonPath.<List<Number>>read(json(get(departuresPath("Pailin", "Koh Kong"), dara)),
                "$[?(@.id == '" + trip + "')].seatsLeft")).containsExactly(38);

        // A taken seat cannot be booked again, and a booking that asks for it holds nothing.
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1C", "1A"), "payment", "card"), dara)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Seat 1A has just been taken. Choose another seat.");
        get(seatsPath(trip), dara).expectStatus().isOk()
                .expectBody().jsonPath("$.rows[0][3].status").isEqualTo("available");

        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1C"), "payment", "card"), dara)
                .expectStatus().isCreated();
        get(seatsPath(trip), sokha).expectStatus().isOk()
                .expectBody().jsonPath("$.rows[0][3].status").isEqualTo("takenByMale");

        // Each buyer sees their own bookings, with the seats.
        get("/buyer/bookings", dara).expectStatus().isOk()
                .expectBody().jsonPath("$[0].seats[0]").isEqualTo("1C");
    }

    @Test
    void seatChoicesAreChecked() {
        String bus = newBusCompany("+85570000804", "Checks Bus Co");
        String trip = publishApproved(bus, "Pursat", "Battambang", "vip");
        String buyer = registerBuyer("+85570000815", "Mealea Sam", "female");

        List<String> nine = List.of("1A", "1B", "1C", "2A", "2B", "2C", "3A", "3B", "3C");
        assertRefused(buyer, trip, nine, "Choose at most 8 seats per booking.");
        assertRefused(buyer, trip, List.of(), "Choose at least one seat.");
        assertRefused(buyer, trip, List.of("1A", "1A"), "Choose each seat once.");
        // A VIP coach is 2+1: no seat D, and no row 11.
        assertRefused(buyer, trip, List.of("1D"), "Seat 1D does not exist on this bus.");
        assertRefused(buyer, trip, List.of("11A"), "Seat 11A does not exist on this bus.");
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1A"), "payment", "cash"), buyer)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose how to pay.");
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1A"), "payment", "card",
                "promoCode", "NOPE"), buyer).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("NOPE is not a valid promo code.");

        // None of that held a seat; a promo code works as for any ticket.
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("1A", "1B"), "payment", "card",
                "promoCode", "D2D10"), buyer).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.subtotalCents").isEqualTo(3000)
                .jsonPath("$.discountCents").isEqualTo(300)
                .jsonPath("$.totalCents").isEqualTo(2700);
    }

    @Test
    void theOwnerSeesSeatsAndCancellingFreesThem() {
        String bus = newBusCompany("+85570000805", "Cancel Bus Co");
        String trip = publishApproved(bus, "Svay Rieng", "Prey Veng", "seater");
        String sokha = registerBuyer("+85570000816", "Neary Pov", "female");
        String dara = registerBuyer("+85570000817", "Sambath Tith", "male");

        String booking = read(post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("2A", "2B"),
                "payment", "card"), sokha).expectStatus().isCreated().expectBody(), "$.id");

        // The merchant sees the booking as an online sale with its seats.
        String all = json(get("/merchant/bookings", bus));
        assertThat(JsonPath.<List<List<String>>>read(all, "$[?(@.id == '" + booking + "')].seats"))
                .containsExactly(List.of("2A", "2B"));
        assertThat(JsonPath.<List<String>>read(all, "$[?(@.id == '" + booking + "')].channel"))
                .containsExactly("online");
        get("/merchant/events/" + trip + "/summary", bus).expectStatus().isOk()
                .expectBody().jsonPath("$.sold").isEqualTo(2).jsonPath("$.left").isEqualTo(38);

        // The owner cancels; the buyer is refunded and the seats are free for someone else.
        post("/merchant/bookings/" + booking + "/cancel", Map.of("reason", "eventChanged"), bus)
                .expectStatus().isOk()
                .expectBody().jsonPath("$.status").isEqualTo("cancelled")
                .jsonPath("$.seats[0]").isEqualTo("2A");
        get(seatsPath(trip), dara).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.rows[1][0].status").isEqualTo("available")
                .jsonPath("$.rows[1][1].status").isEqualTo("available");
        get("/merchant/events/" + trip + "/summary", bus).expectStatus().isOk()
                .expectBody().jsonPath("$.sold").isEqualTo(0).jsonPath("$.left").isEqualTo(40);

        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("2A"), "payment", "card"), dara)
                .expectStatus().isCreated();
        get("/buyer/bookings/" + booking, sokha).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("cancelled")
                .jsonPath("$.seats[0]").isEqualTo("2A")
                .jsonPath("$.cancellation.reason").isEqualTo("eventChanged");
    }

    @Test
    void aDoorSaleTakesTheNextFreeSeats() {
        String bus = newBusCompany("+85570000806", "Door Bus Co");
        String trip = publishApproved(bus, "Takeo", "Kampong Chhnang", "sleeper");
        String buyer = registerBuyer("+85570000818", "Chenda Roth", "female");

        post("/merchant/events/" + trip + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "Seat", "quantity", 2)),
                "buyerPhone", "+85512000706", "payment", "cash"), bus).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.channel").isEqualTo("door")
                .jsonPath("$.seats[0]").isEqualTo("1A")
                .jsonPath("$.seats[1]").isEqualTo("1B");

        // Sleepers are 1+1 beds: the door sale's seats are plain taken, with no passenger shown.
        get(seatsPath(trip), buyer).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.seatType").isEqualTo("Sleeper · 1+1")
                .jsonPath("$.rows[0][0].status").isEqualTo("taken")
                .jsonPath("$.rows[0][2].status").isEqualTo("taken")
                .jsonPath("$.rows[1][0].status").isEqualTo("available");

        // The next door sale carries on from there, and the buyer cannot take those seats.
        post("/merchant/events/" + trip + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "Seat", "quantity", 1)),
                "buyerPhone", "+85512000707", "payment", "cash"), bus).expectStatus().isCreated()
                .expectBody().jsonPath("$.seats[0]").isEqualTo("2A");
        post("/buyer/bookings", Map.of("eventId", trip, "seats", List.of("2A"), "payment", "card"), buyer)
                .expectStatus().isEqualTo(409);
    }

    @Test
    void busEndpointsAreForBuyersOnly() {
        String bus = newBusCompany("+85570000807", "Roles Bus Co");
        String trip = publishApproved(bus, "Kep", "Kampot", "seater");

        get("/catalog/bus/routes", bus).expectStatus().isForbidden();
        get(seatsPath(trip), accessTokenFor(OWNER)).expectStatus().isForbidden();
        get("/catalog/bus/routes", adminToken()).expectStatus().isForbidden();
        post("/merchant/events/bus-trips", trip("Kep", "Kampot", "seater"), registerBuyer("+85570000819",
                "Visal Oum", "male")).expectStatus().isForbidden();
    }

    private void assertRefused(String buyer, String trip, List<String> seats, String message) {
        post("/buyer/bookings", Map.of("eventId", trip, "seats", seats, "payment", "card"), buyer)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo(message);
    }

    /** A new bus company that Pin has approved; returns its owner's access token. */
    private String newBusCompany(String phone, String name) {
        String owner = registerBusiness(phone, name, "bus");
        approveBusinessOf(owner);
        return owner;
    }

    private String publish(String owner, String origin, String destination, String coach) {
        return read(post("/merchant/events/bus-trips", trip(origin, destination, coach), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
    }

    private String publishApproved(String owner, String origin, String destination, String coach) {
        String id = publish(owner, origin, destination, coach);
        approveEvent(id);
        return id;
    }

    private static Map<String, Object> trip(String origin, String destination, String coach) {
        return Map.of("origin", origin, "destination", destination, "startsAt", DAY + "T08:00:00",
                "durationMinutes", 210, "coachType", coach, "priceCents", 1500, "boardingPoint", "Test Terminal",
                "boardingAddress", "St 1, Test Town", "about", "A test tour with a picnic.",
                "amenities", List.of("A/C", "Water"));
    }

    private List<String> routes(String buyer) {
        return JsonPath.read(json(get("/catalog/bus/routes", buyer)), "$[*].id");
    }

    private static String departuresPath(String origin, String destination) {
        // The client encodes the spaces in place names itself.
        return "/catalog/bus/departures?origin=" + origin + "&destination=" + destination + "&date=" + DAY;
    }

    private static String seatsPath(String trip) {
        return "/catalog/bus/departures/" + trip + "/seats";
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectStatus().isOk().expectBody().returnResult().getResponseBody(),
                StandardCharsets.UTF_8);
    }
}
