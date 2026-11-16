package com.ticket.app.backend.shared.config;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * Stops the server from starting with its development-only switches on anywhere but a
 * development machine. Those switches make every phone's sign-in code the same, let anyone reset
 * an admin's password, and create sample businesses with known logins: harmless on a laptop, a
 * total takeover of a real deployment. The warnings they print are easy to miss, so a wrong
 * profile in a deployment would run unnoticed until someone abused it.
 *
 * <p>With any of the switches on, the server starts only when all of these hold:
 * <ul>
 *   <li>the {@code dev} or {@code test} profile is active, and</li>
 *   <li>no {@code prod} or {@code production} profile is active, and</li>
 *   <li>the database is on this machine (localhost), so a deployment with a real database refuses
 *       even if someone set the dev profile.</li>
 * </ul>
 * Nothing is checked, and no database connection opened, when the switches are off.
 */
@Component
class DevSwitchesGuard {

    static final Set<String> DEV_PROFILES = Set.of("dev", "test");
    static final Set<String> PRODUCTION_PROFILES = Set.of("prod", "production");
    private static final Set<String> LOCAL_HOSTS = Set.of("localhost", "127.0.0.1", "::1", "[::1]");
    private static final Pattern JDBC_HOST = Pattern.compile("^jdbc:[a-z0-9]+://(\\[[^\\]]+\\]|[^/:?;,]+)");

    @Autowired
    DevSwitchesGuard(PinProperties properties, Environment environment, DataSource dataSource) {
        this(properties, Set.of(environment.getActiveProfiles()), () -> databaseUrl(dataSource));
    }

    /** @param databaseUrl asked for only when a switch is on */
    DevSwitchesGuard(PinProperties properties, Set<String> activeProfiles, Supplier<String> databaseUrl) {
        List<String> on = switchesOn(properties);
        if (on.isEmpty()) {
            return;
        }
        List<String> problems = problems(activeProfiles, databaseUrl.get());
        if (!problems.isEmpty()) {
            throw new IllegalStateException(message(on, problems));
        }
    }

    /** The development-only switches that are on, in words. */
    static List<String> switchesOn(PinProperties properties) {
        List<String> on = new ArrayList<>();
        if (properties.otp().usesDevCode()) {
            on.add("every sign-in code is the development code (pin.otp.dev-code)");
        }
        if (properties.adminSignIn().devPasswordReset()) {
            on.add("anyone can reset an admin's password (pin.admin-sign-in.dev-password-reset)");
        }
        if (properties.demoData()) {
            on.add("the demo businesses and demo admin are created (pin.demo-data)");
        }
        return on;
    }

    /** What is wrong with running the development switches here; empty when this is a development machine. */
    static List<String> problems(Set<String> activeProfiles, String jdbcUrl) {
        Set<String> profiles = activeProfiles.stream().map(p -> p.toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());
        List<String> problems = new ArrayList<>();
        if (profiles.stream().anyMatch(PRODUCTION_PROFILES::contains)) {
            problems.add("a production profile is active");
        }
        if (profiles.stream().noneMatch(DEV_PROFILES::contains)) {
            problems.add("neither the dev nor the test profile is active");
        }
        String host = hostOf(jdbcUrl);
        if (host == null) {
            problems.add("the database address could not be read, so it cannot be shown to be on this machine");
        } else if (!LOCAL_HOSTS.contains(host)) {
            problems.add("the database is not on this machine (" + host + ")");
        }
        return problems;
    }

    /** {@code localhost} for {@code jdbc:postgresql://localhost:5434/pin}; null when there is no host. */
    static String hostOf(String jdbcUrl) {
        if (jdbcUrl == null) {
            return null;
        }
        Matcher matcher = JDBC_HOST.matcher(jdbcUrl.strip().toLowerCase(Locale.ROOT));
        return matcher.find() ? matcher.group(1) : null;
    }

    private static String message(List<String> on, List<String> problems) {
        return "Refusing to start: development-only settings are on but this is not a development "
                + "machine.\n  On: " + String.join("; ", on)
                + ".\n  Because: " + String.join("; ", problems)
                + ".\n  These settings let anyone sign in as anyone or become an admin. Turn them off "
                + "(unset the dev profile, pin.otp.dev-code, pin.admin-sign-in.dev-password-reset and "
                + "pin.demo-data), or run locally with --spring.profiles.active=dev against a local database.";
    }

    private static String databaseUrl(DataSource dataSource) {
        try (Connection connection = dataSource.getConnection()) {
            return connection.getMetaData().getURL();
        } catch (SQLException e) {
            // Without an address we cannot tell where this runs, so the guard refuses.
            return null;
        }
    }
}
