package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.model.SalesSummary;

/** The sales numbers of one ticket type. */
public record TicketTypeSalesResponse(String name, int quantity, int sold, int checkedIn, int left) {

    public static TicketTypeSalesResponse of(SalesSummary.TicketTypeSales sales) {
        return new TicketTypeSalesResponse(sales.name(), sales.quantity(), sales.sold(), sales.checkedIn(),
                sales.left());
    }
}
