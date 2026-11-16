package com.ticket.app.backend.shared.config;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.ZoneId;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Settings under {@code pin:} in application.yml.
 *
 * @param timeZone        where Pin's events happen; decides what "today" is and how
 *                        event times are shown
 * @param commissionRate  percent Pin keeps of online sales, for newly published events
 * @param otp             sign-in codes
 * @param registrationTtl how long a confirmed new number may take to fill in the
 *                        register or join form
 * @param sessionTtl      how long a device stays signed in
 * @param adminSessionTtl how long a browser stays signed in to the admin panel
 * @param adminSignIn     admins' passwords
 * @param adminAccount    an admin created, or given a new password, on startup
 * @param signInRequestsPerMinute sign-in and sign-up requests one client address may
 *                        make per minute
 * @param demoData        create the demo businesses, their events and bookings, and a
 *                        demo admin on startup
 */
@ConfigurationProperties("pin")
public record PinProperties(
        @DefaultValue("Asia/Phnom_Penh") ZoneId timeZone,
        @DefaultValue("5") BigDecimal commissionRate,
        @DefaultValue Otp otp,
        @DefaultValue("30m") Duration registrationTtl,
        @DefaultValue("30d") Duration sessionTtl,
        @DefaultValue("12h") Duration adminSessionTtl,
        @DefaultValue AdminSignIn adminSignIn,
        @DefaultValue AdminAccount adminAccount,
        @DefaultValue("30") int signInRequestsPerMinute,
        boolean demoData) {

    /**
     * @param maxWrongPasswords wrong passwords in a row before an admin's sign-in is locked
     * @param lockFor           how long it then stays locked, even for the right password
     * @param devPasswordReset  development only: "forgot password" in the admin panel sets
     *                          a new password straight away, with no proof the person is
     *                          that admin
     */
    public record AdminSignIn(
            @DefaultValue("5") int maxWrongPasswords,
            @DefaultValue("15m") Duration lockFor,
            boolean devPasswordReset) {
    }

    /**
     * On startup, the admin with this email address is created if there is none, and
     * given this password if it is not theirs yet. This is how the first admin is
     * added, and how a forgotten password is replaced. Nothing happens without an email.
     *
     * @param email    the admin's email address
     * @param password at least 12 characters
     * @param name     shown in the panel and on payouts; used when the admin is created
     */
    public record AdminAccount(
            String email,
            String password,
            @DefaultValue("Pin admin") String name) {

        public boolean isSet() {
            return email != null && !email.isBlank();
        }
    }

    /**
     * @param ttl             how long a code can be used
     * @param resendAfter     how soon the same number can ask for another code
     * @param maxSendsPerHour codes one number can be sent per hour
     * @param maxAttempts     wrong guesses allowed before the code stops working
     * @param devCode         development only: when set, every code is this one and no SMS is sent
     */
    public record Otp(
            @DefaultValue("5m") Duration ttl,
            @DefaultValue("30s") Duration resendAfter,
            @DefaultValue("5") int maxSendsPerHour,
            @DefaultValue("5") int maxAttempts,
            String devCode) {

        public boolean usesDevCode() {
            return devCode != null && !devCode.isBlank();
        }
    }
}
