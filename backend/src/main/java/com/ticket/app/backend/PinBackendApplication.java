package com.ticket.app.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration;

/**
 * The Pin API server.
 *
 * <p>Sign-in is by phone number and a texted code, so Spring's default
 * username-and-password user is switched off.
 */
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
@ConfigurationPropertiesScan
public class PinBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(PinBackendApplication.class, args);
    }
}
