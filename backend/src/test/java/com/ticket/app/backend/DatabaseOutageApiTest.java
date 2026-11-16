package com.ticket.app.backend;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * The database stops answering in the middle of the day. Scans must fail fast with
 * 503 "unavailable" (not hang, not "sign in again"), and the same scan must work as
 * soon as the database is back, without restarting the server.
 *
 * <p>Runs with its own server and database (the property below gives it its own
 * Spring context), so freezing the database does not disturb the other tests.
 */
@TestPropertySource(properties = "spring.datasource.hikari.pool-name=database-outage-test")
class DatabaseOutageApiTest extends ApiTest {

    @Autowired
    PostgreSQLContainer postgres;

    @Test
    void whileTheDatabaseIsDownAScanAnswers503QuicklyAndWorksWhenItIsBack() {
        String owner = registerBusiness("+85570000600", "Outage Test Club");
        approveBusinessOf(owner);
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));
        String event = read(post("/merchant/events", Map.of(
                "name", "Outage Run", "startsAt", today + "T23:30:00", "venue", "Riverside", "kind", "marathon",
                "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 10))), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(event);
        String booking = read(post("/merchant/events/" + event + "/door-sales", Map.of(
                "lines", List.of(Map.of("ticketType", "5K", "quantity", 1)),
                "buyerPhone", "+85512000600", "payment", "cash"), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        Map<String, Object> scan = Map.of("eventId", event, "code", booking, "attemptId", UUID.randomUUID().toString());

        freezeDatabase();
        try {
            long started = System.nanoTime();
            post("/merchant/checkins", scan, owner)
                    .expectStatus().isEqualTo(503)
                    .expectBody()
                    .jsonPath("$.code").isEqualTo("unavailable")
                    .jsonPath("$.message").isEqualTo("Pin can't save right now. Please try again in a moment.");
            // Well before the app gives up waiting (15 s), so the scanner sees the message.
            assertThat(Duration.ofNanos(System.nanoTime() - started)).isLessThan(Duration.ofSeconds(12));
        } finally {
            thawDatabase();
        }

        // Back: the very same scan goes through, and the session still works.
        post("/merchant/checkins", scan, owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("admitted");
        get("/me", owner).expectStatus().isOk();
    }

    /** Pauses the database container: it stops answering, like a crashed or unreachable server. */
    private void freezeDatabase() {
        postgres.getDockerClient().pauseContainerCmd(postgres.getContainerId()).exec();
    }

    private void thawDatabase() {
        postgres.getDockerClient().unpauseContainerCmd(postgres.getContainerId()).exec();
    }
}
