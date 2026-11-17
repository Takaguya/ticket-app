package com.ticket.app.backend.identity.service;

import java.time.Clock;
import java.util.Optional;

import com.ticket.app.backend.business.service.BusinessService;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.business.model.StaffMemberRemoved;
import com.ticket.app.backend.identity.model.Session;
import com.ticket.app.backend.identity.repository.SessionRepository;
import com.ticket.app.backend.identity.model.TokenHash;
import com.ticket.app.backend.shared.config.PinProperties;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

/**
 * Signed-in devices. The app sends its access token as
 * {@code Authorization: Bearer <token>} on every request.
 */
@Service
public class SessionService {

    private final SessionRepository sessions;
    private final BusinessService business;
    private final Clock clock;
    private final PinProperties properties;

    public SessionService(SessionRepository sessions, BusinessService business, Clock clock,
                          PinProperties properties) {
        this.sessions = sessions;
        this.business = business;
        this.clock = clock;
        this.properties = properties;
    }

    public SignedIn start(StaffMember member) {
        Session.Started started = Session.start(member.id(), clock.instant(), properties.sessionTtl());
        sessions.add(started.session());
        return new SignedIn(started.accessToken(), member);
    }

    /**
     * Who an access token signs in. Empty when it is unknown or expired, or the
     * member has left the team since.
     */
    public Optional<StaffMember> resolve(String accessToken) {
        return sessions.find(TokenHash.of(accessToken))
                .filter(session -> session.isActiveAt(clock.instant()))
                .flatMap(session -> business.currentMember(session.staffId()));
    }

    /** Signs the device out: its token stops working. */
    public void end(String accessToken) {
        sessions.remove(TokenHash.of(accessToken));
    }

    /** A member taken off the team is signed out on every device, in the same transaction. */
    @EventListener
    void onStaffMemberRemoved(StaffMemberRemoved event) {
        sessions.removeAllOf(event.staffId());
    }
}
