package com.ticket.app.backend.admin.dto;

import java.time.LocalDate;

/** {@code period}: the days figures are counted for; {@code today}: today in Pin's time zone. */
public record OverviewResponse(PeriodResponse period, LocalDate today, double commissionRate) {
}
