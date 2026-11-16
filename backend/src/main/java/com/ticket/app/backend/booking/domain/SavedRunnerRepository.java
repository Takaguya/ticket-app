package com.ticket.app.backend.booking.domain;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.buyer.domain.BuyerId;

/** Where the runner a buyer saved for their next race is kept: one per buyer. */
public interface SavedRunnerRepository {

    Optional<Runner> find(BuyerId buyer);

    /** Saves the runner, replacing the buyer's earlier one. */
    void save(BuyerId buyer, Runner runner, Instant savedAt);
}
