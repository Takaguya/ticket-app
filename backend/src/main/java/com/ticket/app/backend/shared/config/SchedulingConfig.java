package com.ticket.app.backend.shared.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Runs {@code @Scheduled} jobs, such as the nightly sign-in housekeeping. */
@Configuration(proxyBeanMethods = false)
@EnableScheduling
class SchedulingConfig {
}
