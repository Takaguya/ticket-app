package com.ticket.app.backend.business.model;

/**
 * A member was taken off their team. Other modules react to it, e.g. sign-in ends
 * the member's sessions, without the business module knowing about them.
 */
public record StaffMemberRemoved(StaffId staffId) {
}
