package com.ticket.app.backend.admin.domain;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Objects;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventKind;

/**
 * One event as the back office lists it, with its business and how many tickets are
 * sold. {@code startsAt} is local to the venue. {@code imageVersion} is null unless the event has a
 * cover image ({@link com.ticket.app.backend.event.domain.EventImage#version()}).
 */
public record EventOverview(EventId id, String name, String venue, LocalDateTime startsAt, BusinessId merchantId,
                            String merchantName, BusinessStatus merchantStatus, boolean approved, int sold,
                            int capacity, EventKind kind, Long imageVersion) {

    /** What the admin sees in the status column. */
    public enum Status {
        /** New, waiting for an admin. */
        AWAITING_APPROVAL("awaitingApproval"),
        /** Approved and happening today. */
        LIVE("live"),
        /** Approved, in the future. */
        ON_SALE("onSale"),
        /** Approved, but its business is suspended, so nothing sells. */
        PAUSED("paused"),
        /** Its day is over, whether or not it was ever approved. */
        ENDED("ended");

        private final String code;

        Status(String code) {
            this.code = code;
        }

        public String code() {
            return code;
        }
    }

    public EventOverview {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(venue, "venue");
        Objects.requireNonNull(startsAt, "startsAt");
        Objects.requireNonNull(merchantId, "merchantId");
        Objects.requireNonNull(merchantName, "merchantName");
        Objects.requireNonNull(merchantStatus, "merchantStatus");
        Objects.requireNonNull(kind, "kind");
    }

    public Status statusOn(LocalDate today) {
        // A place is open every day: its date is a placeholder, so it is never past.
        LocalDate day = kind.isOpenEveryDay() ? today : startsAt.toLocalDate();
        if (day.isBefore(today)) {
            return Status.ENDED;
        }
        if (!approved) {
            return Status.AWAITING_APPROVAL;
        }
        if (merchantStatus == BusinessStatus.SUSPENDED) {
            return Status.PAUSED;
        }
        return day.isEqual(today) ? Status.LIVE : Status.ON_SALE;
    }

    /** Only events still to come can be approved. */
    public boolean canBeApprovedOn(LocalDate today) {
        return statusOn(today) == Status.AWAITING_APPROVAL;
    }
}
