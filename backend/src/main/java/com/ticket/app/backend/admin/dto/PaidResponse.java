package com.ticket.app.backend.admin.dto;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

import com.ticket.app.backend.admin.service.BackOfficeService;

/** A payout that was paid to a merchant. */
public record PaidResponse(String id, String merchantId, String merchantName, long grossCents, long commissionCents,
                    long refundsCents, long netCents, int bookingCount, LocalDateTime paidAt, String paidBy) {

    public static PaidResponse of(BackOfficeService.Paid paid, ZoneId zone) {
        var payout = paid.payout();
        return new PaidResponse(payout.id().toString(), payout.businessId().toString(), paid.businessName(),
                payout.gross().cents(), payout.commission().cents(), payout.refunds().cents(),
                payout.net().cents(), payout.bookingCount(),
                LocalDateTime.ofInstant(payout.paidAt(), zone).truncatedTo(ChronoUnit.SECONDS),
                payout.paidBy().name());
    }
}
