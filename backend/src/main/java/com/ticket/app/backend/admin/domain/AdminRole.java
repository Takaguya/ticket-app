package com.ticket.app.backend.admin.domain;

/** What an admin may do in the back office. */
public enum AdminRole {

    /** Everything an admin does, and adding and removing admins. */
    SUPER_ADMIN,

    /** Approvals, suspensions, bookings and payouts; not adding or removing admins. */
    ADMIN;

    public boolean managesAdmins() {
        return this == SUPER_ADMIN;
    }
}
