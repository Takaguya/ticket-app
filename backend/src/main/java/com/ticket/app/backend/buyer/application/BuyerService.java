package com.ticket.app.backend.buyer.application;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Optional;

import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.buyer.domain.BuyerId;
import com.ticket.app.backend.buyer.domain.BuyerRepository;
import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Buyers' accounts. Used by sign-up and by the user app's screens.
 *
 * <p>Registering runs inside sign-up's transaction, which decides what a refusal
 * undoes.
 */
@Service
public class BuyerService {

    private final BuyerRepository buyers;
    private final Clock clock;

    public BuyerService(BuyerRepository buyers, Clock clock) {
        this.buyers = buyers;
        this.clock = clock;
    }

    /** Creates the account for a confirmed phone number. */
    @Transactional(propagation = Propagation.MANDATORY)
    public Buyer register(PhoneNumber phone, String name, Gender gender, LocalDate dateOfBirth, String email) {
        Buyer buyer = Buyer.register(phone, name, gender, dateOfBirth, email, LocalDate.now(clock));
        if (!buyers.tryAdd(buyer)) {
            throw BusinessRuleException.conflict("This number already has a Pin account. Please sign in.");
        }
        return buyer;
    }

    public Optional<Buyer> withPhone(PhoneNumber phone) {
        return buyers.findByPhone(phone);
    }

    public Optional<Buyer> find(BuyerId id) {
        return buyers.find(id);
    }
}
