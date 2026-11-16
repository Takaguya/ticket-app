package com.ticket.app.backend.admin.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.Optional;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.shared.domain.Money;
import com.ticket.app.backend.shared.domain.PhoneNumber;

/**
 * One business as the back office lists it: who owns it, how many events it has and
 * what it sold online in the period.
 *
 * @param owner       null only if the owner's record is missing
 * @param onlineSales online bookings in the period, not cancelled
 * @param commission  Pin's share of {@code onlineSales}
 */
public record MerchantOverview(BusinessId id, String name, BusinessType type, BusinessStatus status, Owner owner,
                               int events, Money onlineSales, Money commission, Instant registeredAt) {

    public record Owner(String name, PhoneNumber phone) {
    }

    public MerchantOverview {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(type, "type");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(onlineSales, "onlineSales");
        Objects.requireNonNull(commission, "commission");
        Objects.requireNonNull(registeredAt, "registeredAt");
    }

    public Optional<Owner> ownerIfKnown() {
        return Optional.ofNullable(owner);
    }
}
