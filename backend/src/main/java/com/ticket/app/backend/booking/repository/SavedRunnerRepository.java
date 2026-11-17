package com.ticket.app.backend.booking.repository;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.booking.model.Runner;

/** Where the runner a buyer saved for their next race is kept: one per buyer. */
public interface SavedRunnerRepository {

    Optional<Runner> find(BuyerId buyer);

    /** Saves the runner, replacing the buyer's earlier one. */
    void save(BuyerId buyer, Runner runner, Instant savedAt);
}
