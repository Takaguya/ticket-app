package com.ticket.app.backend.buyer.repository;

import java.util.Optional;

import com.ticket.app.backend.shared.model.PhoneNumber;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.buyer.model.BuyerId;

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
