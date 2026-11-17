package com.ticket.app.backend.admin.dto;

import java.time.LocalDate;

import com.ticket.app.backend.admin.service.BackOfficeService;

/** The days the figures are counted for, both included. */
public record PeriodResponse(LocalDate from, LocalDate to) {

    public static PeriodResponse of(BackOfficeService.Period period) {
        return new PeriodResponse(period.from(), period.to());
    }
}
