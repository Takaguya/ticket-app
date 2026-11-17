package com.ticket.app.backend.booking.dto;

import java.util.List;

import com.ticket.app.backend.booking.model.SalesSummary;

/** The sales numbers of an event (or of today's visitors, for a place), matching the merchant app's SalesSummary. */
public record SummaryResponse(int capacity, int sold, int left, int checkedIn, int bookingCount, long onlineCents,
                       long doorCents, long revenueCents, long commissionCents, double commissionRate,
                       long netCents, List<TicketTypeSalesResponse> byTicketType) {

    public static SummaryResponse of(SalesSummary summary) {
        return new SummaryResponse(summary.capacity(), summary.sold(), summary.left(), summary.checkedIn(),
                summary.bookingCount(), summary.online().cents(), summary.door().cents(),
                summary.revenue().cents(), summary.commission().cents(), summary.commissionRate().doubleValue(),
                summary.net().cents(),
                summary.byTicketType().stream().map(TicketTypeSalesResponse::of).toList());
    }
}
