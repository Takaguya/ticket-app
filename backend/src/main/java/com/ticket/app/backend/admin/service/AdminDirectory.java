package com.ticket.app.backend.admin.service;

import java.time.Instant;
import java.util.Optional;

import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.admin.model.AdminId;
import com.ticket.app.backend.admin.repository.AdminRepository;
import com.ticket.app.backend.admin.model.AdminRole;
import com.ticket.app.backend.shared.model.EmailAddress;
import org.springframework.stereotype.Service;

/** Who Pin's admins are. Used by sign-in to find the admin an email address belongs to. */
@Service
public class AdminDirectory {

    private final AdminRepository admins;

    public AdminDirectory(AdminRepository admins) {
        this.admins = admins;
    }

    public Optional<Admin> find(AdminId id) {
        return admins.find(id);
    }

    public Optional<Admin> findByEmail(EmailAddress email) {
        return admins.findByEmail(email);
    }

    /**
     * Adds an admin from the server settings: a super admin, so the first admin can add
     * the others. They cannot sign in until they are given a password.
     */
    public Admin add(String name, EmailAddress email) {
        return add(name, email, AdminRole.SUPER_ADMIN, null);
    }

    /**
     * Adds an admin. They cannot sign in until they are given a password.
     *
     * @param addedBy the admin adding them; null when added from the server settings
     */
    public Admin add(String name, EmailAddress email, AdminRole role, AdminId addedBy) {
        Admin admin = Admin.create(name, email, role);
        admins.add(admin, addedBy);
        return admin;
    }

    /** Marks the admin removed. @return false when there is no such admin any more */
    public boolean remove(AdminId id, AdminId removedBy, Instant now) {
        return admins.remove(id, removedBy, now);
    }

    /** @return false when there is no such admin any more */
    public boolean changeRole(AdminId id, AdminRole role) {
        return admins.changeRole(id, role);
    }
}
