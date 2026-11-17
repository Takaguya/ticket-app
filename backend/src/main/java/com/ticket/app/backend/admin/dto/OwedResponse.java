package com.ticket.app.backend.admin.dto;

import com.ticket.app.backend.admin.service.BackOfficeService;

/**
 * What Pin owes one merchant now. {@code refundsCents}: the merchant's share of paid-out bookings it
 * cancelled since, which Pin refunded to the buyers and takes back from this payout.
 */
public record OwedResponse(String merchantId, String merchantName, long grossCents, long commissionCents,
                    long refundsCents, long netCents, int bookingCount) {

    public static OwedResponse of(BackOfficeService.Owed owed) {
        var due = owed.due();
        return new OwedResponse(due.businessId().toString(), owed.businessName(), due.gross().cents(),
                due.commission().cents(), due.refunds().cents(), due.net().cents(), due.bookings().size());
    }
}
