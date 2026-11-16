package com.ticket.app.backend.shared.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.ZoneId;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;

/** The development-only switches may be on only on a development machine, or the server will not start. */
class DevSwitchesGuardTest {

    private static final String LOCAL = "jdbc:postgresql://localhost:5434/pin";
    private static final String REMOTE = "jdbc:postgresql://db.pin.example:5432/pin?sslmode=require";

    private static PinProperties properties(String devCode, boolean devPasswordReset, boolean demoData) {
        return new PinProperties(ZoneId.of("Asia/Phnom_Penh"), BigDecimal.valueOf(5),
                new PinProperties.Otp(Duration.ofMinutes(5), Duration.ofSeconds(30), 5, 5, devCode),
                Duration.ofMinutes(30), Duration.ofDays(30), Duration.ofHours(12),
                new PinProperties.AdminSignIn(5, Duration.ofMinutes(15), devPasswordReset),
                new PinProperties.AdminAccount(null, null, "Pin admin"), 30, demoData);
    }

    private static final PinProperties ALL_OFF = properties(null, false, false);
    private static final PinProperties ALL_ON = properties("123456", true, true);

    @Test
    void withTheSwitchesOffAnythingGoesAndTheDatabaseIsNotEvenAsked() {
        AtomicInteger asked = new AtomicInteger();

        assertThatCode(() -> new DevSwitchesGuard(ALL_OFF, Set.of("prod"), () -> {
            asked.incrementAndGet();
            return REMOTE;
        })).doesNotThrowAnyException();
        assertThat(asked).hasValue(0);
        // A blank dev code is off too: that is how application.yml ships it.
        assertThatCode(() -> new DevSwitchesGuard(properties("  ", false, false), Set.of(), () -> REMOTE))
                .doesNotThrowAnyException();
    }

    @Test
    void aDevelopmentMachineMayHaveThemOn() {
        assertThatCode(() -> new DevSwitchesGuard(ALL_ON, Set.of("dev"), () -> LOCAL)).doesNotThrowAnyException();
        assertThatCode(() -> new DevSwitchesGuard(ALL_ON, Set.of("test"), () -> "jdbc:postgresql://127.0.0.1:55001/test"))
                .doesNotThrowAnyException();
        assertThatCode(() -> new DevSwitchesGuard(ALL_ON, Set.of("DEV"), () -> "jdbc:postgresql://[::1]:5432/pin"))
                .doesNotThrowAnyException();
    }

    @Test
    void anyOneSwitchIsEnoughToBeChecked() {
        for (PinProperties one : new PinProperties[] {
                properties("123456", false, false), properties(null, true, false), properties(null, false, true)}) {
            assertThatThrownBy(() -> new DevSwitchesGuard(one, Set.of(), () -> LOCAL))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("neither the dev nor the test profile is active");
        }
    }

    @Test
    void aDeploymentWithTheDevProfileAndARealDatabaseRefuses() {
        assertThatThrownBy(() -> new DevSwitchesGuard(ALL_ON, Set.of("dev"), () -> REMOTE))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Refusing to start")
                .hasMessageContaining("the database is not on this machine (db.pin.example)")
                .hasMessageContaining("pin.otp.dev-code")
                .hasMessageContaining("pin.admin-sign-in.dev-password-reset")
                .hasMessageContaining("pin.demo-data");
    }

    @Test
    void aProductionProfileRefusesEvenOnALocalDatabase() {
        assertThatThrownBy(() -> new DevSwitchesGuard(ALL_ON, Set.of("dev", "prod"), () -> LOCAL))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("a production profile is active");
        assertThatThrownBy(() -> new DevSwitchesGuard(ALL_ON, Set.of("production"), () -> LOCAL))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("a production profile is active");
    }

    @Test
    void aDatabaseWhoseAddressCannotBeReadCountsAsNotLocal() {
        assertThatThrownBy(() -> new DevSwitchesGuard(ALL_ON, Set.of("dev"), () -> null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("cannot be shown to be on this machine");
    }

    @Test
    void allTheProblemsAreListedTogether() {
        assertThat(DevSwitchesGuard.problems(Set.of("prod"), REMOTE)).containsExactly(
                "a production profile is active",
                "neither the dev nor the test profile is active",
                "the database is not on this machine (db.pin.example)");
        assertThat(DevSwitchesGuard.problems(Set.of("dev"), LOCAL)).isEmpty();
    }

    @Test
    void theHostIsReadFromTheJdbcUrl() {
        assertThat(DevSwitchesGuard.hostOf("jdbc:postgresql://localhost:5434/pin")).isEqualTo("localhost");
        assertThat(DevSwitchesGuard.hostOf("jdbc:postgresql://DB.Pin.Example/pin")).isEqualTo("db.pin.example");
        assertThat(DevSwitchesGuard.hostOf("jdbc:postgresql://[::1]:5432/pin")).isEqualTo("[::1]");
        // Several hosts or a look-alike: only what comes first is read, and "localhost.evil.example" is not local.
        assertThat(DevSwitchesGuard.hostOf("jdbc:postgresql://localhost.evil.example/pin")).isEqualTo("localhost.evil.example");
        assertThat(DevSwitchesGuard.hostOf("jdbc:postgresql:///pin")).isNull();
        assertThat(DevSwitchesGuard.hostOf("not a url")).isNull();
        assertThat(DevSwitchesGuard.hostOf(null)).isNull();
        assertThat(DevSwitchesGuard.problems(Set.of("dev"), "jdbc:postgresql://localhost.evil.example/pin"))
                .containsExactly("the database is not on this machine (localhost.evil.example)");
    }
}
