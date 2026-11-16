package com.ticket.app.backend.identity.domain;

import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.admin.domain.AdminId;

/**
 * The admins for the Admins page and the profile page, read across the admins and their
 * passwords. Removed admins are not included.
 */
public interface AdminSummaries {

    /** Every admin who has an email address, the earliest added first. */
    List<AdminSummary> all();

    Optional<AdminSummary> find(AdminId id);
}
