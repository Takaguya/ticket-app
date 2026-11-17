package com.ticket.app.backend.identity.service;

import java.time.Clock;
import java.util.List;

import com.ticket.app.backend.admin.service.AdminDirectory;
import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.admin.model.AdminId;
import com.ticket.app.backend.admin.model.AdminRole;
import com.ticket.app.backend.identity.model.AdminPassword;
import com.ticket.app.backend.identity.repository.AdminPasswordRepository;
import com.ticket.app.backend.identity.repository.AdminSummaries;
import com.ticket.app.backend.identity.model.AdminSummary;
import com.ticket.app.backend.identity.model.PasswordHasher;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.EmailAddress;
import com.ticket.app.backend.shared.model.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The Admins page: who Pin's admins are, and, for super admins only, adding and
 * removing them. A new admin gets a temporary password, shown once to the super admin
 * who added them to pass on; at their first sign-in they must choose their own.
 *
 * <p>The web layer lets only super admins add and remove; the checks here are a second
 * line, should a caller ever skip it.
 */
@Service
public class AdminTeamService {

    private static final Logger log = LoggerFactory.getLogger(AdminTeamService.class);

    private final AdminDirectory admins;
    private final AdminPasswordRepository passwords;
    private final AdminSummaries summaries;
    private final AdminSessionService sessions;
    private final PasswordHasher hasher;
    private final Clock clock;

    public AdminTeamService(AdminDirectory admins, AdminPasswordRepository passwords, AdminSummaries summaries,
                            AdminSessionService sessions, PasswordHasher hasher, Clock clock) {
        this.admins = admins;
        this.passwords = passwords;
        this.summaries = summaries;
        this.sessions = sessions;
        this.hasher = hasher;
        this.clock = clock;
    }

    public List<AdminSummary> list() {
        return summaries.all();
    }

    /** The signed-in admin, as their profile shows them. */
    public AdminSummary profile(Admin me) {
        return summaries.find(me.id()).orElseThrow(() -> new NotFoundException("This admin does not exist."));
    }

    /** Adds the admin with a new temporary password. 409 when the address is already an admin's. */
    @Transactional
    public Added add(Admin addedBy, String name, String email, AdminRole role) {
        requireSuperAdmin(addedBy);
        EmailAddress address = EmailAddress.of(email);
        if (admins.findByEmail(address).isPresent()) {
            throw BusinessRuleException.conflict(address + " is already a Pin admin.");
        }
        Admin admin = admins.add(name, address, role, addedBy.id());
        String temporaryPassword = AdminPassword.newTemporaryPassword();
        passwords.save(AdminPassword.temporary(admin.id(), temporaryPassword, hasher));
        log.info("Admin {} added {} {}", addedBy.email(), role, address);
        return new Added(admin, temporaryPassword);
    }

    /**
     * Removes the admin: they are signed out everywhere at once and can no longer sign
     * in. Their name stays on the payouts they made. Nobody can remove themselves, so
     * there is always a super admin left.
     */
    @Transactional
    public void remove(Admin removedBy, AdminId id) {
        requireSuperAdmin(removedBy);
        if (id.equals(removedBy.id())) {
            throw BusinessRuleException.conflict("You can't remove yourself. Ask another super admin.");
        }
        if (!admins.remove(id, removedBy.id(), clock.instant())) {
            throw new NotFoundException("This admin does not exist.");
        }
        passwords.remove(id);
        sessions.endAllFor(id);
        log.info("Admin {} removed admin {}", removedBy.email(), id);
    }

    /**
     * Gives the admin another role. It counts from their next request. Nobody changes
     * their own role, so there is always a super admin left.
     */
    @Transactional
    public AdminSummary changeRole(Admin changedBy, AdminId id, AdminRole role) {
        requireSuperAdmin(changedBy);
        if (id.equals(changedBy.id())) {
            throw BusinessRuleException.conflict("You can't change your own role. Ask another super admin.");
        }
        if (!admins.changeRole(id, role)) {
            throw new NotFoundException("This admin does not exist.");
        }
        log.info("Admin {} made admin {} {}", changedBy.email(), id, role);
        return summaries.find(id).orElseThrow(() -> new NotFoundException("This admin does not exist."));
    }

    private static void requireSuperAdmin(Admin admin) {
        if (!admin.managesAdmins()) {
            throw new IllegalStateException("Only super admins add or remove admins; " + admin.id() + " is not one");
        }
    }

    /** The new admin, and the temporary password to pass on. Only ever shown once. */
    public record Added(Admin admin, String temporaryPassword) {

        /** Never print the password, e.g. in logs. */
        @Override
        public String toString() {
            return "Added[admin=" + admin + ", temporaryPassword=hidden]";
        }
    }
}
