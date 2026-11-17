package com.ticket.app.backend.identity.service;

import java.time.Clock;
import java.util.Optional;

import com.ticket.app.backend.buyer.service.BuyerService;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.identity.model.BuyerSession;
import com.ticket.app.backend.identity.repository.BuyerSessionRepository;
import com.ticket.app.backend.identity.model.TokenHash;
import com.ticket.app.backend.shared.config.PinProperties;
import org.springframework.stereotype.Service;

/**
 * Signed-in user app devices. The app sends its access token as
 * {@code Authorization: Bearer <token>} on every request.
 */
@Service
public class BuyerSessionService {

    private final BuyerSessionRepository sessions;
    private final BuyerService buyers;
    private final Clock clock;
    private final PinProperties properties;

    public BuyerSessionService(BuyerSessionRepository sessions, BuyerService buyers, Clock clock,
                               PinProperties properties) {
        this.sessions = sessions;
        this.buyers = buyers;
        this.clock = clock;
        this.properties = properties;
    }

    public BuyerSignedIn start(Buyer buyer) {
        BuyerSession.Started started = BuyerSession.start(buyer.id(), clock.instant(), properties.sessionTtl());
        sessions.add(started.session());
        return new BuyerSignedIn(started.accessToken(), buyer);
    }

    /** Who an access token signs in. Empty when it is unknown or expired. */
    public Optional<Buyer> resolve(String accessToken) {
        return sessions.find(TokenHash.of(accessToken))
                .filter(session -> session.isActiveAt(clock.instant()))
                .flatMap(session -> buyers.find(session.buyerId()));
    }

    /** Signs the device out: its token stops working. */
    public void end(String accessToken) {
        sessions.remove(TokenHash.of(accessToken));
    }
}
