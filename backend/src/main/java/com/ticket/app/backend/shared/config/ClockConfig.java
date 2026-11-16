package com.ticket.app.backend.shared.config;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The one clock the application reads, set to Pin's time zone. Services pass the
 * time into the domain, so the domain never reads a clock itself.
 */
@Configuration(proxyBeanMethods = false)
class ClockConfig {

    @Bean
    Clock clock(PinProperties properties) {
        return Clock.system(properties.timeZone());
    }
}
