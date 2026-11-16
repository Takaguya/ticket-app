package com.ticket.app.backend.business.application;

import java.time.Clock;
import java.util.Optional;
import java.util.function.UnaryOperator;

import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessRepository;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.business.domain.JoinCode;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.business.domain.StaffMemberRemoved;
import com.ticket.app.backend.business.domain.StaffRepository;
import com.ticket.app.backend.business.domain.Team;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.DomainException;
import com.ticket.app.backend.shared.domain.NotFoundException;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Businesses and who works for them. Used by sign-up and by the staff screens.
 *
 * <p>Registering and joining run inside sign-up's transaction, and a refusal there
 * does not by itself roll it back: sign-up decides what a refusal undoes.
 */
@Service
public class BusinessService {

    private static final int JOIN_CODE_DRAWS = 20;

    private final BusinessRepository businesses;
    private final StaffRepository staff;
    private final Clock clock;
    private final ApplicationEventPublisher events;

    public BusinessService(BusinessRepository businesses, StaffRepository staff, Clock clock,
                           ApplicationEventPublisher events) {
        this.businesses = businesses;
        this.staff = staff;
        this.clock = clock;
        this.events = events;
    }

    /** The owner's business with its current staff and join code. */
    public Team team(StaffMember owner) {
        return new Team(owner.business(), staff.findCurrentByBusiness(owner.businessId()));
    }

    /**
     * Takes a scanner off the owner's team. Announces {@link StaffMemberRemoved} in the
     * same transaction, so their sessions end with it.
     */
    @Transactional
    public void removeMember(StaffMember owner, StaffId memberId) {
        StaffMember member = team(owner).memberToRemove(memberId);
        staff.markRemoved(member.id(), clock.instant());
        events.publishEvent(new StaffMemberRemoved(member.id()));
    }

    /** Replaces the business's join code. Scanners who already joined stay on the team. */
    @Transactional
    public JoinCode newJoinCode(StaffMember owner) {
        JoinCode current = owner.business().joinCode();
        for (int draw = 0; draw < JOIN_CODE_DRAWS; draw++) {
            JoinCode candidate = JoinCode.random();
            if (!candidate.equals(current) && businesses.tryChangeJoinCode(owner.businessId(), candidate)) {
                return candidate;
            }
        }
        throw new IllegalStateException("Could not find a free join code");
    }

    /** Creates a business with {@code phone} as its owner. */
    @Transactional(propagation = Propagation.MANDATORY, noRollbackFor = DomainException.class)
    public StaffMember registerBusiness(String businessName, BusinessType type, String ownerName, PhoneNumber phone) {
        Business business = Business.register(businessName, type);
        int draws = 1;
        while (!businesses.tryAdd(business)) {
            if (++draws > JOIN_CODE_DRAWS) {
                throw new IllegalStateException("Could not find a free join code");
            }
            business = business.withJoinCode(JoinCode.random());
        }
        return add(StaffMember.owner(business, ownerName, phone));
    }

    /**
     * Adds {@code phone} as a scanner of the business whose join code this is.
     * Empty when no business has that code.
     */
    @Transactional(propagation = Propagation.MANDATORY, noRollbackFor = DomainException.class)
    public Optional<StaffMember> joinAsScanner(JoinCode joinCode, String name, PhoneNumber phone) {
        return businesses.findByJoinCode(joinCode)
                .map(business -> add(StaffMember.scanner(business, name, phone)));
    }

    public Optional<Business> find(BusinessId id) {
        return businesses.find(id);
    }

    /**
     * The business, held until the transaction ends, e.g. while it is paid out, so two
     * admins never pay the same sales.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public Business lock(BusinessId id) {
        return businesses.findAndLock(id).orElseThrow(BusinessService::businessNotFound);
    }

    /** An admin lets a new business sell. */
    @Transactional
    public Business approve(BusinessId id) {
        return changeStatus(id, Business::approve);
    }

    /** An admin stops a business from selling. Tickets it already sold still scan. */
    @Transactional
    public Business suspend(BusinessId id) {
        return changeStatus(id, Business::suspend);
    }

    /** An admin lets a suspended business sell again. */
    @Transactional
    public Business reinstate(BusinessId id) {
        return changeStatus(id, Business::reinstate);
    }

    public Optional<StaffMember> currentMember(StaffId id) {
        return staff.findCurrent(id);
    }

    public Optional<StaffMember> currentMemberWithPhone(PhoneNumber phone) {
        return staff.findCurrentByPhone(phone);
    }

    /** Locks the business so two admins changing it at once are decided one after the other. */
    private Business changeStatus(BusinessId id, UnaryOperator<Business> change) {
        Business changed = change.apply(lock(id));
        businesses.updateStatus(changed);
        return changed;
    }

    private static NotFoundException businessNotFound() {
        return new NotFoundException("This business does not exist.");
    }

    private StaffMember add(StaffMember member) {
        if (!staff.tryAdd(member)) {
            throw BusinessRuleException.conflict("This phone number already has an account. Log in instead.");
        }
        return member;
    }
}
