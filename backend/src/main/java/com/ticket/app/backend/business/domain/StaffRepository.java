package com.ticket.app.backend.business.domain;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.shared.domain.PhoneNumber;

/** Where owners and scanners are kept. Removed members are not "current". */
public interface StaffRepository {

    Optional<StaffMember> findCurrent(StaffId id);

    Optional<StaffMember> findCurrentByPhone(PhoneNumber phone);

    /** The business's current members: the owner first, then scanners in the order they joined. */
    List<StaffMember> findCurrentByBusiness(BusinessId businessId);

    /**
     * Takes a member off the team. They are kept, marked removed, so past check-ins
     * still name them; their sessions stop working and their number is free again.
     */
    void markRemoved(StaffId id, Instant at);

    /**
     * Saves a new member unless the phone number belongs to a current member of any
     * business. A number works for one business at a time.
     *
     * @return whether it was saved
     */
    boolean tryAdd(StaffMember member);
}
