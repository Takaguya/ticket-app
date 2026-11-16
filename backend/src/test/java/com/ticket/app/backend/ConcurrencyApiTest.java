package com.ticket.app.backend;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.function.IntFunction;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;

/**
 * Requests that race each other, sent at the same instant over real HTTP: two
 * scanners scanning one ticket, door sales for the last tickets, repeated taps on
 * sign-in. Each must be decided once, and nothing may fail with a server error.
 */
class ConcurrencyApiTest extends ApiTest {

    private static final String MARATHON = "30000000-0000-7000-8000-000000000001";

    @Value("${local.server.port}")
    int port;

    private final HttpClient client = HttpClient.newBuilder()
            .version(HttpClient.Version.HTTP_1_1)
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    @Test
    void manyScansOfOneTicketAtOnceAdmitItExactlyOnce() throws Exception {
        String owner = accessTokenFor(OWNER);
        String scanner = accessTokenFor(SECOND_SCANNER);
        String bookings = new String(get("/merchant/events/" + MARATHON + "/bookings?status=open", scanner)
                .expectStatus().isOk().expectBody().returnResult().getResponseBody());
        String bookingId = JsonPath.read(bookings, "$[1].id");

        // Two staff members, ten scans each, all at the same moment.
        List<HttpResponse<String>> answers = allAtOnce(20, i -> rawPost("/merchant/checkins",
                "{\"eventId\":\"%s\",\"code\":\"%s\"}".formatted(MARATHON, bookingId),
                i % 2 == 0 ? owner : scanner));

        assertThat(answers).allSatisfy(answer -> assertThat(answer.statusCode()).isEqualTo(200));
        assertThat(results(answers)).containsOnly("admitted", "alreadyUsed");
        assertThat(results(answers).stream().filter("admitted"::equals)).hasSize(1);
    }

    @Test
    void doorSalesAtOnceNeverSellMoreTicketsThanAreLeft() throws Exception {
        String owner = accessTokenFor(OWNER);
        LocalDate day = LocalDate.now(ZoneId.of("Asia/Phnom_Penh")).plusDays(3);
        String event = read(post("/merchant/events", Map.of(
                "name", "Five Ticket Run", "startsAt", day + "T06:00:00", "venue", "Riverside", "kind", "marathon",
                "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 5))), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(event);

        List<HttpResponse<String>> answers = allAtOnce(12, i -> rawPost("/merchant/events/" + event + "/door-sales",
                "{\"lines\":[{\"ticketType\":\"5K\",\"quantity\":1}],\"buyerPhone\":\"+85512000%03d\",\"payment\":\"cash\"}"
                        .formatted(i),
                owner));

        assertThat(statuses(answers)).containsOnly(201, 409);
        assertThat(statuses(answers).stream().filter(status -> status == 201)).hasSize(5);
        String summary = new String(get("/merchant/events/" + event + "/summary", owner)
                .expectStatus().isOk().expectBody().returnResult().getResponseBody());
        assertThat(JsonPath.<Integer>read(summary, "$.sold")).isEqualTo(5);
        assertThat(JsonPath.<Integer>read(summary, "$.left")).isZero();
    }

    @Test
    void onlineAndDoorSalesForOneDayOfAPlaceAtOnceNeverPassItsDailyLimit() throws Exception {
        String owner = registerBusiness("+85570000403", "Race Gate Park Co", "admission");
        approveBusinessOf(owner);
        String place = read(post("/merchant/events/places", Map.of("name", "Race Gate Park", "venue", "Race Gate",
                "ticketTypes", List.of(Map.of("name", "Adult", "priceCents", 500, "dailyLimit", 3))), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(place);
        String buyer = registerBuyer("+85570000404", "Kanha Ros", "female");
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));
        LocalDate tomorrow = today.plusDays(1);
        String online = "{\"eventId\":\"%s\",\"lines\":[{\"ticketType\":\"Adult\",\"quantity\":1}],"
                + "\"payment\":\"card\",\"visitDate\":\"%s\"}";

        // The app and the gate sell today's last tickets at the same moment, while tomorrow sells too.
        List<HttpResponse<String>> answers = allAtOnce(12, i -> switch (i % 3) {
            case 0 -> rawPost("/buyer/bookings", online.formatted(place, today), buyer);
            case 1 -> rawPost("/merchant/events/" + place + "/door-sales",
                    "{\"lines\":[{\"ticketType\":\"Adult\",\"quantity\":1}],\"buyerPhone\":\"+85512001%03d\",\"payment\":\"cash\"}"
                            .formatted(i), owner);
            default -> rawPost("/buyer/bookings", online.formatted(place, tomorrow), buyer);
        });

        List<Integer> forToday = new ArrayList<>();
        List<Integer> forTomorrow = new ArrayList<>();
        for (int i = 0; i < answers.size(); i++) {
            (i % 3 == 2 ? forTomorrow : forToday).add(answers.get(i).statusCode());
        }
        assertThat(forToday).containsOnly(201, 409);
        assertThat(forToday.stream().filter(status -> status == 201)).hasSize(3);
        assertThat(forTomorrow).containsOnly(201, 409);
        assertThat(forTomorrow.stream().filter(status -> status == 201)).hasSize(3);
        for (LocalDate day : List.of(today, tomorrow)) {
            String left = new String(get("/catalog/places/" + place + "/availability?date=" + day, buyer)
                    .expectStatus().isOk().expectBody().returnResult().getResponseBody());
            assertThat(JsonPath.<Integer>read(left, "$.ticketTypes[0].left")).isZero();
        }
    }

    @Test
    void oneScanRetriedManyTimesAtOnceAdmitsOnceAndEveryAnswerSaysAdmitted() throws Exception {
        String scanner = accessTokenFor(SECOND_SCANNER);
        String bookings = new String(get("/merchant/events/" + MARATHON + "/bookings?status=open", scanner)
                .expectStatus().isOk().expectBody().returnResult().getResponseBody());
        String bookingId = JsonPath.read(bookings, "$[2].id");
        String attempt = UUID.randomUUID().toString();

        // A flaky connection: the app's retries of one scan arrive together with the original.
        List<HttpResponse<String>> answers = allAtOnce(10, i -> rawPost("/merchant/checkins",
                "{\"eventId\":\"%s\",\"code\":\"%s\",\"attemptId\":\"%s\"}".formatted(MARATHON, bookingId, attempt),
                scanner));

        assertThat(results(answers)).containsOnly("admitted");
        assertThat(answers.stream().map(answer -> JsonPath.<String>read(answer.body(), "$.booking.checkIn.at")).distinct())
                .hasSize(1);
    }

    @Test
    void oneDoorSaleRetriedManyTimesAtOnceIsRecordedOnce() throws Exception {
        String owner = accessTokenFor(OWNER);
        String attempt = UUID.randomUUID().toString();

        List<HttpResponse<String>> answers = allAtOnce(8, i -> rawPost("/merchant/events/" + MARATHON + "/door-sales",
                "{\"lines\":[{\"ticketType\":\"10K\",\"quantity\":1}],\"buyerPhone\":\"+85512000555\","
                        + "\"payment\":\"cash\",\"attemptId\":\"%s\"}".formatted(attempt),
                owner));

        assertThat(statuses(answers)).containsOnly(201);
        assertThat(answers.stream().map(answer -> JsonPath.<String>read(answer.body(), "$.id")).distinct()).hasSize(1);
    }

    @Test
    void codesAskedForAtOnceForANewNumberAreSentOnce() throws Exception {
        List<HttpResponse<String>> answers = allAtOnce(10, i -> rawPost("/auth/otp",
                "{\"phone\":\"+85570000400\",\"purpose\":\"login\"}", null));

        assertThat(statuses(answers)).containsOnly(204, 429);
        assertThat(statuses(answers).stream().filter(status -> status == 204)).hasSize(1);
    }

    @Test
    void oneRegistrationTokenUsedSeveralTimesAtOnceMakesOneAccount() throws Exception {
        sendCode("+85570000401");
        String registrationToken = read(verify("+85570000401", CODE).expectStatus().isOk().expectBody(),
                "$.registrationToken");

        List<HttpResponse<String>> answers = allAtOnce(6, i -> rawPost("/merchant/staff/join",
                "{\"registrationToken\":\"%s\",\"name\":\"Twin %d\",\"joinCode\":\"482913\"}"
                        .formatted(registrationToken, i), null));

        assertThat(statuses(answers)).containsOnly(201, 400);
        assertThat(statuses(answers).stream().filter(status -> status == 201)).hasSize(1);
        assertThat(answers.stream().filter(answer -> answer.statusCode() == 400))
                .allSatisfy(answer -> assertThat(answer.body()).contains("invalid_registration"));
    }

    @Test
    void adminsPayingOneBusinessAtOncePayItOnce() throws Exception {
        String admin = adminToken();
        String giantIbis = "10000000-0000-7000-8000-000000000004";
        String payouts = new String(get("/admin/payouts", admin).expectStatus().isOk().expectBody()
                .returnResult().getResponseBody());
        long owed = JsonPath.<List<Number>>read(payouts,
                "$.owed[?(@.merchantId == '" + giantIbis + "')].netCents").getFirst().longValue();

        List<HttpResponse<String>> answers = allAtOnce(6, i -> rawPost("/admin/payouts",
                "{\"merchantId\":\"%s\",\"netCents\":%d}".formatted(giantIbis, owed), admin));

        assertThat(statuses(answers)).containsOnly(201, 409);
        assertThat(statuses(answers).stream().filter(status -> status == 201)).hasSize(1);
        String after = new String(get("/admin/payouts", admin).expectStatus().isOk().expectBody()
                .returnResult().getResponseBody());
        assertThat(JsonPath.<List<Object>>read(after, "$.owed[?(@.merchantId == '" + giantIbis + "')]")).isEmpty();
        assertThat(JsonPath.<List<Object>>read(after, "$.paid[?(@.merchantId == '" + giantIbis + "')]")).hasSize(1);
    }

    @Test
    void approvalsOfOneBusinessAtOnceApproveItOnce() throws Exception {
        String owner = registerBusiness("+85570000402", "Twin Approval Tours");
        String businessId = read(get("/me", owner).expectStatus().isOk().expectBody(), "$.business.id");

        List<HttpResponse<String>> answers = allAtOnce(6, i -> rawPost(
                "/admin/merchants/" + businessId + "/approve", "{}", adminToken()));

        assertThat(statuses(answers)).containsOnly(200, 409);
        assertThat(statuses(answers).stream().filter(status -> status == 200)).hasSize(1);
    }

    // ------------------------------------------------------------------ helpers

    /** Runs {@code count} requests in parallel, released together, and waits for all answers. */
    private List<HttpResponse<String>> allAtOnce(int count, IntFunction<HttpRequest> request) throws Exception {
        CountDownLatch ready = new CountDownLatch(count);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<HttpResponse<String>>> futures = new ArrayList<>();
        try (ExecutorService pool = Executors.newFixedThreadPool(count)) {
            for (int i = 0; i < count; i++) {
                HttpRequest next = request.apply(i);
                futures.add(pool.submit(() -> {
                    ready.countDown();
                    go.await();
                    return client.send(next, HttpResponse.BodyHandlers.ofString());
                }));
            }
            ready.await();
            go.countDown();
            List<HttpResponse<String>> answers = new ArrayList<>();
            for (Future<HttpResponse<String>> future : futures) {
                answers.add(future.get());
            }
            return answers;
        }
    }

    /** A JSON POST sent with Java's own HTTP client, so many can be in flight at once. */
    private HttpRequest rawPost(String path, String json, String accessToken) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .timeout(Duration.ofSeconds(20))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json));
        if (accessToken != null) {
            builder.header("Authorization", "Bearer " + accessToken);
        }
        return builder.build();
    }

    private static List<Integer> statuses(List<HttpResponse<String>> answers) {
        return answers.stream().map(HttpResponse::statusCode).toList();
    }

    private static List<String> results(List<HttpResponse<String>> answers) {
        return answers.stream().map(answer -> JsonPath.<String>read(answer.body(), "$.result")).toList();
    }
}
