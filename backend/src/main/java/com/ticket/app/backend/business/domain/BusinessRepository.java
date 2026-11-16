package com.ticket.app.backend.business.domain;

import java.util.Optional;

/** Where businesses are kept. */
public interface BusinessRepository {

    Optional<Business> find(BusinessId id);

    /**
     * The business, held until the transaction ends. Changing its status, and paying
     * it out, lock it, so two admins never act on it at the same moment.
     */
    Optional<Business> findAndLock(BusinessId id);

    Optional<Business> findByJoinCode(JoinCode joinCode);

    /**
     * Saves a new business unless another business already uses its join code.
     *
     * @return whether it was saved
     */
    boolean tryAdd(Business business);

    /**
     * Gives the business a new join code unless another business uses it. The old
     * code stops working at once.
     *
     * @return whether it was changed
     */
    boolean tryChangeJoinCode(BusinessId businessId, JoinCode joinCode);

    /** Saves a changed status. */
    void updateStatus(Business business);
}
