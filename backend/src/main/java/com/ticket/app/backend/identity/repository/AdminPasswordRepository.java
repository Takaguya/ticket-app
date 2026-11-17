package com.ticket.app.backend.identity.repository;

import java.util.Optional;

import com.ticket.app.backend.admin.model.AdminId;
import com.ticket.app.backend.identity.model.AdminPassword;

/** Where admins' passwords are kept. */
public interface AdminPasswordRepository {

    /** The admin's password, locked until the transaction ends, so sign-ins at once are counted one by one. */
    Optional<AdminPassword> findAndLock(AdminId adminId);

    /** Adds the password, or replaces the admin's current one. */
    void save(AdminPassword password);

    /** Whether the admin still has a temporary password, so must choose their own first. */
    boolean mustChange(AdminId adminId);

    /** Deletes the admin's password, e.g. when they are removed. */
    void remove(AdminId adminId);

    /** How many admins have a password, so can sign in. */
    int count();
}
