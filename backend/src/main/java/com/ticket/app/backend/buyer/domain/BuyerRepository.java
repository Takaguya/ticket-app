package com.ticket.app.backend.buyer.domain;

import java.util.Optional;

import com.ticket.app.backend.shared.domain.PhoneNumber;

/** Where buyers are kept. */
public interface BuyerRepository {

    Optional<Buyer> find(BuyerId id);

    Optional<Buyer> findByPhone(PhoneNumber phone);

    /**
     * Saves a new buyer unless the phone number already has an account.
     *
     * @return whether it was saved
     */
    boolean tryAdd(Buyer buyer);
}
