package com.ticket.app.backend.admin.repository;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.admin.model.BookingOverview;
import com.ticket.app.backend.admin.model.EventOverview;
import com.ticket.app.backend.admin.model.MerchantOverview;

/**
 * The back office's lists, across every business. Read-only: changes go through the
 * business, event and booking modules.
 */
public interface BackOfficeReports {

    /**
     * Every business: active ones first, the best-selling first, then those waiting
     * for approval, then suspended ones.
     *
     * @param salesFrom  the start of the period online sales are counted for
     * @param salesUntil just after its end
     */
    List<MerchantOverview> merchants(Instant salesFrom, Instant salesUntil);

    /** Every event of every business, with tickets sold. */
    List<EventOverview> events();

    /**
     * The newest bookings matching {@code query}: part of a booking ID, buyer, event or
     * business name, or 3 or more digits of the buyer's phone number. Empty matches all.
     * Page {@code page} (from 1) of {@code size} bookings each, newest first.
     *
     * @param bookedFrom  only bookings made from then; null for no limit
     * @param bookedUntil only bookings made before then; null for no limit
     */
    BookingOverview.Page bookings(String query, Instant bookedFrom, Instant bookedUntil, int page, int size);

    /** Every business's name. */
    Map<BusinessId, String> businessNames();
}
