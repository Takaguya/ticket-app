package com.ticket.app.backend.admin.dto;

import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.admin.service.BackOfficeService;

/** {@code owed}: what Pin owes now, largest first. {@code paid}: payouts this period, newest first. */
public record PayoutsResponse(List<OwedResponse> owed, List<PaidResponse> paid) {

    public static PayoutsResponse of(BackOfficeService.Payouts payouts, ZoneId zone) {
        return new PayoutsResponse(
                payouts.owed().stream().map(OwedResponse::of).toList(),
                payouts.paid().stream().map(paid -> PaidResponse.of(paid, zone)).toList());
    }
}
