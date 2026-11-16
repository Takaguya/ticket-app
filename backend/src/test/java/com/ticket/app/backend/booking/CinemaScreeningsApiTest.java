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
 * Cinema screenings, from a cinema publishing one to buyers choosing seats and the owner
 * cancelling: who may publish, what buyers see (films, showtimes by cinema, the hall's seats),
 * seats never sold twice. Every test makes its own cinema and film titles, so the demo's
 * screenings and the other tests are never touched.
 */
class CinemaScreeningsApiTest extends ApiTest {

    private static final LocalDate DAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh")).plusDays(4);

    @Test
    void onlyACinemaPublishesScreeningsAndTheyWaitForApproval() {
        String cinema = newCinema("+85570000901", "Test Cinema Co");

        post("/merchant/events/screenings", screening("Test Film One", "Test Cinema, Hall A", "standard"), cinema)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Test Film One")
                .jsonPath("$.kind").isEqualTo("cinema")
                .jsonPath("$.approved").isEqualTo(false)
                .jsonPath("$.venue").isEqualTo("Test Cinema, Hall A")
                .jsonPath("$.capacity").isEqualTo(80)
                .jsonPath("$.ticketTypes[0].name").isEqualTo("Seat")
                .jsonPath("$.ticketTypes[0].priceCents").isEqualTo(600)
                .jsonPath("$.ticketTypes[0].quantity").isEqualTo(80)
                .jsonPath("$.screening.filmTitle").isEqualTo("Test Film One")
                .jsonPath("$.screening.hall").isEqualTo("Hall 3")
                .jsonPath("$.screening.hallSize").isEqualTo("standard")
                .jsonPath("$.screening.hallLabel").isEqualTo("Standard hall · 80 seats")
                .jsonPath("$.screening.seats").isEqualTo(80);

        // The other kinds of business cannot publish one, and a cinema cannot publish an event.
        post("/merchant/events/screenings", screening("Sneaky", "Anywhere", "small"), accessTokenFor(OWNER))
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Only cinemas publish screenings.");
        post("/merchant/events", Map.of("name", "A Marathon", "startsAt", DAY + "T06:00:00", "venue", "Riverside",
                "kind", "marathon", "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 5))),
                cinema).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("A cinema publishes screenings, not events.");
        post("/merchant/events", Map.of("name", "Sneaky Film", "startsAt", DAY + "T06:00:00", "venue", "Riverside",
                "kind", "cinema", "ticketTypes", List.of(Map.of("name", "Seat", "priceCents", 1000, "quantity", 5))),
                accessTokenFor(OWNER)).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Publish screenings with the screening form.");
    }

    @Test
    void aScreeningNeedsAFilmAHallAndAPrice() {
        String cinema = newCinema("+85570000902", "Rules Cinema Co");

        post("/merchant/events/screenings", withTitle("x"), cinema).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter the film's title.");
        post("/merchant/events/screenings", screening("Rules Film", "Rules Cinema", "huge"), cinema)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose the size of the hall.");
        post("/merchant/events/screenings", screening("Rules Film", "Rules Cinema", "vip"), cinema)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose the size of the hall.");
        post("/merchant/events/screenings", withRuntime(5), cinema).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The film runs between 10 minutes and 10 hours.");

        post("/merchant/events/screenings", screening("Small Film", "Rules Cinema", "small"), cinema)
                .expectStatus().isCreated().expectBody().jsonPath("$.capacity").isEqualTo(48);
        post("/merchant/events/screenings", screening("Large Film", "Rules Cinema", "large"), cinema)
                .expectStatus().isCreated().expectBody().jsonPath("$.capacity").isEqualTo(120);

        // A bus company cannot use a hall's size, nor a cinema a coach's.
        String bus = registerBusiness("+85570000903", "Hall Bus Co", "bus");
        approveBusinessOf(bus);
        post("/merchant/events/bus-trips", Map.of("origin", "A Town", "destination", "B Town",
                "startsAt", DAY + "T08:00:00", "durationMinutes", 120, "coachType", "standard", "priceCents", 1000,
                "boardingPoint", "Terminal"), bus).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose the kind of coach.");
    }

    @Test
    void buyersFindFilmsByCinemaAndBookHallSeatsNeverTwice() {
        String cinema = newCinema("+85570000904", "Seats Cinema Co");
        String first = publish(cinema, "Seat Film", "Seats Cinema, Mall", "standard");
        String second = publish(cinema, "Seat Film", "Seats Cinema, Riverside", "small");
        String sokha = registerBuyer("+85570000914", "Rida Seng", "female");
        String dara = registerBuyer("+85570000915", "Vuthy Ly", "male");

        // Waiting for approval: not on offer.
        assertThat(films(sokha)).doesNotContain("seat-film");
        get(seatsPath(first), sokha).expectStatus().isNotFound();

        approveEvent(first);
        approveEvent(second);
        String films = json(get("/catalog/cinema/films", sokha));
        // The two screenings are one film.
        assertThat(JsonPath.<List<String>>read(films, "$[?(@.id == 'seat-film')].name")).containsExactly("Seat Film");
        assertThat(JsonPath.<List<String>>read(films, "$[?(@.id == 'seat-film')].rating")).containsExactly("PG-13");
        assertThat(JsonPath.<List<Number>>read(films, "$[?(@.id == 'seat-film')].runtimeMinutes"))
                .containsExactly(112);
        assertThat(JsonPath.<List<Number>>read(films, "$[?(@.id == 'seat-film')].fromPriceCents"))
                .containsExactly(600);
        get("/catalog/cinema/films/seat-film", sokha).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Seat Film")
                .jsonPath("$.genre").isEqualTo("Action")
                .jsonPath("$.about").isEqualTo("A test film.")
                .jsonPath("$.policy").exists();
        get("/catalog/cinema/films/no-such-film", sokha).expectStatus().isNotFound();

        // Its showtimes on the day, by cinema.
        String shows = json(get("/catalog/cinema/films/seat-film/showtimes?date=" + DAY, sokha));
        assertThat(JsonPath.<List<String>>read(shows, "$[*].theatre.name"))
                .containsExactlyInAnyOrder("Seats Cinema, Mall", "Seats Cinema, Riverside");
        assertThat(JsonPath.<List<Number>>read(shows, "$[?(@.theatre.name == 'Seats Cinema, Mall')].showtimes[0].seatsLeft"))
                .containsExactly(80);
        assertThat(JsonPath.<List<Number>>read(shows, "$[?(@.theatre.name == 'Seats Cinema, Riverside')].showtimes[0].seatsLeft"))
                .containsExactly(48);
        assertThat(json(get("/catalog/cinema/films/seat-film/showtimes?date=" + DAY.plusDays(1), sokha)))
                .isEqualTo("[]");

        // The standard hall: 8 rows of 3 + 4 + 3 seats named by letter and number.
        get(seatsPath(first), dara).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.seatType").isEqualTo("Standard hall · 80 seats")
                .jsonPath("$.priceCents").isEqualTo(600)
                .jsonPath("$.rows.length()").isEqualTo(8)
                .jsonPath("$.rows[0].length()").isEqualTo(12)
                .jsonPath("$.rows[0][0].id").isEqualTo("A1")
                .jsonPath("$.rows[0][0].label").isEqualTo("1")
                .jsonPath("$.rows[0][0].detail").isEqualTo("Row A")
                .jsonPath("$.rows[0][3]").isEmpty()
                .jsonPath("$.rows[0][8]").isEmpty()
                .jsonPath("$.rows[7][11].id").isEqualTo("H10");

        post("/buyer/bookings", Map.of("eventId", first, "seats", List.of("F5", "F6"), "payment", "card"), sokha)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.seats[0]").isEqualTo("F5")
                .jsonPath("$.seats[1]").isEqualTo("F6")
                .jsonPath("$.totalCents").isEqualTo(1200)
                .jsonPath("$.event.kind").isEqualTo("cinema")
                .jsonPath("$.event.name").isEqualTo("Seat Film")
                .jsonPath("$.event.venue").isEqualTo("Seats Cinema, Mall")
                .jsonPath("$.event.screening.hall").isEqualTo("Hall 3")
                .jsonPath("$.event.screening.runtimeMinutes").isEqualTo(112);

        // A hall's seats are just taken: nobody sees who sits there.
        get(seatsPath(first), dara).expectStatus().isOk()
                .expectBody()
                // Row F: F1 F2 F3, the aisle, F4 F5 F6 F7, the aisle, F8 F9 F10.
                .jsonPath("$.rows[5][5].id").isEqualTo("F5")
                .jsonPath("$.rows[5][5].status").isEqualTo("taken")
                .jsonPath("$.rows[5][6].status").isEqualTo("taken")
                .jsonPath("$.rows[5][7].status").isEqualTo("available");
        assertThat(JsonPath.<List<Number>>read(json(get("/catalog/cinema/films/seat-film/showtimes?date=" + DAY, dara)),
                "$[?(@.theatre.name == 'Seats Cinema, Mall')].showtimes[0].seatsLeft")).containsExactly(78);

        post("/buyer/bookings", Map.of("eventId", first, "seats", List.of("A1", "F6"), "payment", "card"), dara)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Seat F6 has just been taken. Choose another seat.");

        // Seats are the hall's own: no row K, no number 11, no coach seat names.
        for (String bad : List.of("K1", "A11", "1A")) {
            post("/buyer/bookings", Map.of("eventId", first, "seats", List.of(bad), "payment", "card"), dara)
                    .expectStatus().isBadRequest()
                    .expectBody().jsonPath("$.message").isEqualTo("Seat " + bad + " does not exist in this hall.");
        }

        // The small hall has 6 rows of 8.
        get(seatsPath(second), dara).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.rows.length()").isEqualTo(6)
                .jsonPath("$.rows[0][9].id").isEqualTo("A8");
        post("/buyer/bookings", Map.of("eventId", second, "seats", List.of("F9"), "payment", "card"), dara)
                .expectStatus().isBadRequest();
    }

    @Test
    void filmsWithKhmerTitlesKeepTheirOwnIdsAndATitleWithoutLettersIsRefused() {
        String cinema = newCinema("+85570000908", "Khmer Cinema Co");
        String sokha = registerBuyer("+85570000918", "Chenda Ouk", "female");
        String naga = publishApproved(cinema, "នាគ", "Khmer Cinema, Mall", "small");
        String sun = publishApproved(cinema, "ព្រះអាទិត្យ", "Khmer Cinema, Mall", "small");

        // Two different Khmer titles are two films, each with an id that is not empty.
        List<String> ids = JsonPath.read(json(get("/catalog/cinema/films", sokha)), "$[*].id");
        List<String> khmer = ids.stream().filter(id -> !id.isEmpty() && !id.matches("[a-z0-9-]+")).toList();
        assertThat(khmer).hasSize(2).doesNotHaveDuplicates();
        assertThat(ids).doesNotContain("");
        assertThat(naga).isNotEqualTo(sun);

        post("/merchant/events/screenings", screening("!!!", "Khmer Cinema, Mall", "small"), cinema)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The film's title needs letters or digits.");
    }

    @Test
    void theOwnerSeesSeatsCancellingFreesThemAndDoorSalesTakeTheNextOnes() {
        String cinema = newCinema("+85570000905", "Cancel Cinema Co");
        String screening = publishApproved(cinema, "Cancel Film", "Cancel Cinema, Mall", "small");
        String buyer = registerBuyer("+85570000916", "Neary Pov", "female");

        String booking = read(post("/buyer/bookings", Map.of("eventId", screening, "seats", List.of("B3", "B4"),
                "payment", "abaKhqr"), buyer).expectStatus().isCreated().expectBody(), "$.id");
        String all = json(get("/merchant/bookings", cinema));
        assertThat(JsonPath.<List<List<String>>>read(all, "$[?(@.id == '" + booking + "')].seats"))
                .containsExactly(List.of("B3", "B4"));

        // A door sale takes the next free seats, front row first.
        post("/merchant/events/" + screening + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "Seat", "quantity", 3)),
                "buyerPhone", "+85512000905", "payment", "cash"), cinema).expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.seats[0]").isEqualTo("A1")
                .jsonPath("$.seats[1]").isEqualTo("A2")
                .jsonPath("$.seats[2]").isEqualTo("A3");

        post("/merchant/bookings/" + booking + "/cancel", Map.of("reason", "eventChanged"), cinema)
                .expectStatus().isOk().expectBody().jsonPath("$.status").isEqualTo("cancelled");
        get(seatsPath(screening), buyer).expectStatus().isOk()
                .expectBody()
                // The small hall's row B: B1 B2, the aisle, B3 B4 B5 B6, the aisle, B7 B8.
                .jsonPath("$.rows[1][3].id").isEqualTo("B3")
                .jsonPath("$.rows[1][3].status").isEqualTo("available")
                .jsonPath("$.rows[0][0].status").isEqualTo("taken");
        get("/merchant/events/" + screening + "/summary", cinema).expectStatus().isOk()
                .expectBody().jsonPath("$.sold").isEqualTo(3).jsonPath("$.left").isEqualTo(45);

        get("/buyer/bookings/" + booking, buyer).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("cancelled")
                .jsonPath("$.seats[0]").isEqualTo("B3")
                .jsonPath("$.cancellation.refundCents").isEqualTo(1200);
    }

    @Test
    void cinemaEndpointsAreForBuyersOnly() {
        String cinema = newCinema("+85570000906", "Roles Cinema Co");
        String screening = publishApproved(cinema, "Roles Film", "Roles Cinema", "standard");

        get("/catalog/cinema/films", cinema).expectStatus().isForbidden();
        get(seatsPath(screening), accessTokenFor(OWNER)).expectStatus().isForbidden();
        get("/catalog/cinema/films", adminToken()).expectStatus().isForbidden();
        // A bus trip is not a screening.
        String bus = registerBusiness("+85570000907", "Roles Bus Co 2", "bus");
        approveBusinessOf(bus);
        String trip = read(post("/merchant/events/bus-trips", Map.of("origin", "Aa", "destination", "Bb",
                "startsAt", DAY + "T08:00:00", "durationMinutes", 120, "coachType", "seater", "priceCents", 1000,
                "boardingPoint", "Terminal"), bus).expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(trip);
        get(seatsPath(trip), registerBuyer("+85570000917", "Visal Oum", "male")).expectStatus().isNotFound();
    }

    private String newCinema(String phone, String name) {
        String owner = registerBusiness(phone, name, "cinema");
        approveBusinessOf(owner);
        return owner;
    }

    private String publish(String owner, String film, String theatre, String hallSize) {
        return read(post("/merchant/events/screenings", screening(film, theatre, hallSize), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
    }

    private String publishApproved(String owner, String film, String theatre, String hallSize) {
        String id = publish(owner, film, theatre, hallSize);
        approveEvent(id);
        return id;
    }

    private static Map<String, Object> screening(String film, String theatre, String hallSize) {
        return Map.ofEntries(Map.entry("filmTitle", film), Map.entry("rating", "PG-13"), Map.entry("genre", "Action"),
                Map.entry("runtimeMinutes", 112), Map.entry("about", "A test film."), Map.entry("theatre", theatre),
                Map.entry("theatreArea", "Test Mall, Test Town"), Map.entry("hall", "Hall 3"),
                Map.entry("hallSize", hallSize), Map.entry("startsAt", DAY + "T19:00:00"),
                Map.entry("priceCents", 600));
    }

    private static Map<String, Object> withTitle(String title) {
        return screening(title, "Some Cinema", "standard");
    }

    private static Map<String, Object> withRuntime(int minutes) {
        return Map.of("filmTitle", "Short Film", "runtimeMinutes", minutes, "theatre", "Some Cinema", "hall", "Hall 1",
                "hallSize", "small", "startsAt", DAY + "T19:00:00", "priceCents", 600);
    }

    private List<String> films(String buyer) {
        return JsonPath.read(json(get("/catalog/cinema/films", buyer)), "$[*].id");
    }

    private static String seatsPath(String screening) {
        return "/catalog/cinema/showtimes/" + screening + "/seats";
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectStatus().isOk().expectBody().returnResult().getResponseBody(),
                StandardCharsets.UTF_8);
    }
}
