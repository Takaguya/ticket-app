package com.ticket.app.backend.identity.web;

import java.time.ZoneId;

import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.identity.application.AdminSessionService;
import com.ticket.app.backend.identity.application.AdminSignInService;
import com.ticket.app.backend.identity.application.AdminSignedIn;
import com.ticket.app.backend.identity.application.AdminTeamService;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.EmailAddress;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Signing in to the admin panel, with an admin's email address and password. */
@RestController
class AdminAuthController {

    private final AdminSignInService signIn;
    private final AdminSessionService sessions;
    private final AdminTeamService team;
    private final ZoneId zone;

    AdminAuthController(AdminSignInService signIn, AdminSessionService sessions, AdminTeamService team,
                        PinProperties properties) {
        this.signIn = signIn;
        this.sessions = sessions;
        this.team = team;
        this.zone = properties.timeZone();
    }

    /**
     * {@code {"accessToken": "...", "admin": {...}}}; 400 for a wrong email or password,
     * 429 while sign-in is locked after too many wrong passwords.
     */
    @PostMapping("/admin/auth/sign-in")
    AdminSessionResponse signIn(@Valid @RequestBody AdminSignInRequest request) {
        return AdminSessionResponse.of(signIn.signIn(request.email(), request.password()));
    }

    /**
     * {@code {"available": true}} on development servers, where "forgot password" sets a
     * new password straight away; false everywhere else.
     */
    @GetMapping("/admin/auth/password-reset")
    PasswordResetAvailability passwordResetAvailability() {
        return new PasswordResetAvailability(signIn.canResetPasswordsWithoutProof());
    }

    /**
     * Development only: gives the admin the new password and signs them out of every
     * browser. 204; 400 for a short password or an address that is no admin's; 409 on
     * servers where this is off.
     */
    @PostMapping("/admin/auth/password-reset")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void resetPassword(@Valid @RequestBody PasswordResetRequest request) {
        signIn.resetPasswordWithoutProof(request.email(), request.newPassword());
    }

    /** Ends this browser's session; its token stops working. */
    @PostMapping("/admin/auth/sign-out")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void signOut(@RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        SessionAuthenticationFilter.bearerToken(authorization).ifPresent(sessions::end);
    }

    /**
     * Who is signed in, and whether they must choose their own password first. The
     * panel uses it to check a saved session still works.
     */
    @GetMapping("/admin/me")
    AdminResponse me(@AuthenticationPrincipal Admin me) {
        return AdminResponse.of(me, SecurityConfig.isNewAdmin());
    }

    /** The signed-in admin's profile: the same fields as an entry of {@code GET /admin/admins}. */
    @GetMapping("/admin/me/profile")
    AdminTeamController.AdminSummaryResponse profile(@AuthenticationPrincipal Admin me) {
        return AdminTeamController.AdminSummaryResponse.of(team.profile(me), me, zone);
    }

    /**
     * Changes the signed-in admin's password and signs out their other browsers; this
     * one stays signed in. 204; 400 for a wrong current password or a new one that is
     * not allowed; 429 while locked after too many wrong passwords.
     */
    @PostMapping("/admin/me/password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void changePassword(@AuthenticationPrincipal Admin me,
                        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
                        @Valid @RequestBody ChangePasswordRequest request) {
        String accessToken = SessionAuthenticationFilter.bearerToken(authorization).orElseThrow();
        signIn.changePassword(me, accessToken, request.currentPassword(), request.newPassword());
    }

    record AdminSignInRequest(
            @NotBlank(message = "Enter your email address.")
            @Size(max = EmailAddress.MAX_LENGTH, message = "Enter a valid email address.") String email,
            // Far longer than any allowed password; only keeps huge requests out.
            @NotBlank(message = "Enter your password.")
            @Size(max = 1000, message = "The email or password is wrong.") String password) {
    }

    record PasswordResetAvailability(boolean available) {
    }

    record PasswordResetRequest(
            @NotBlank(message = "Enter your email address.")
            @Size(max = EmailAddress.MAX_LENGTH, message = "Enter a valid email address.") String email,
            @NotBlank(message = "Enter a new password.")
            @Size(max = 1000, message = "That password is too long.") String newPassword) {
    }

    record ChangePasswordRequest(
            @NotBlank(message = "Enter your current password.")
            @Size(max = 1000, message = "Your current password is wrong.") String currentPassword,
            @NotBlank(message = "Enter a new password.")
            @Size(max = 1000, message = "That password is too long.") String newPassword) {
    }

    record AdminSessionResponse(String accessToken, AdminResponse admin) {

        static AdminSessionResponse of(AdminSignedIn signedIn) {
            return new AdminSessionResponse(signedIn.accessToken().value(),
                    AdminResponse.of(signedIn.admin(), signedIn.mustChangePassword()));
        }
    }

    /**
     * @param role               {@code superAdmin} or {@code admin}
     * @param mustChangePassword signed in with a temporary password: must choose their own first
     */
    record AdminResponse(String id, String name, String email, String role, boolean mustChangePassword) {

        static AdminResponse of(Admin admin, boolean mustChangePassword) {
            return new AdminResponse(admin.id().toString(), admin.name(), admin.email().value(),
                    AdminTeamController.roleName(admin.role()), mustChangePassword);
        }
    }
}
