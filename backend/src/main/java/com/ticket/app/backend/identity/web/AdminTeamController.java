package com.ticket.app.backend.identity.web;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Locale;

import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.admin.domain.AdminRole;
import com.ticket.app.backend.identity.application.AdminTeamService;
import com.ticket.app.backend.identity.domain.AdminSummary;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.EmailAddress;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** The admin panel's Admins page: who Pin's admins are, and adding one. */
@RestController
@RequestMapping("/admin/admins")
class AdminTeamController {

    private final AdminTeamService team;
    private final ZoneId zone;

    AdminTeamController(AdminTeamService team, PinProperties properties) {
        this.team = team;
        this.zone = properties.timeZone();
    }

    /** Every admin, the earliest added first. {@code you} marks the one asking. */
    @GetMapping
    List<AdminSummaryResponse> list(@AuthenticationPrincipal Admin me) {
        return team.list().stream().map(admin -> AdminSummaryResponse.of(admin, me, zone)).toList();
    }

    /**
     * Super admins only: adds an admin with a new temporary password, which this answer
     * is the only one to show: {@code {id, name, email, role, temporaryPassword}}. 201;
     * 400 for a missing name or a wrong email address; 409 when the address is already
     * an admin's.
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    AddedAdminResponse add(@AuthenticationPrincipal Admin me, @Valid @RequestBody AddAdminRequest request) {
        AdminRole role = "superAdmin".equals(request.role()) ? AdminRole.SUPER_ADMIN : AdminRole.ADMIN;
        AdminTeamService.Added added = team.add(me, request.name(), request.email(), role);
        Admin admin = added.admin();
        return new AddedAdminResponse(admin.id().toString(), admin.name(), admin.email().value(),
                roleName(admin.role()), added.temporaryPassword());
    }

    /**
     * Super admins only: removes the admin. They are signed out at once and can no
     * longer sign in. 204; 404 for an admin that does not exist or was already removed;
     * 409 for yourself.
     */
    @PostMapping("/{adminId}/remove")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void remove(@AuthenticationPrincipal Admin me, @PathVariable String adminId) {
        team.remove(me, AdminId.parse(adminId));
    }

    /**
     * Super admins only: gives the admin another role, from their next request. The
     * admin as listed; 404 for an admin that does not exist or was removed; 409 for
     * yourself.
     */
    @PostMapping("/{adminId}/role")
    AdminSummaryResponse changeRole(@AuthenticationPrincipal Admin me, @PathVariable String adminId,
                                    @Valid @RequestBody ChangeRoleRequest request) {
        AdminRole role = "superAdmin".equals(request.role()) ? AdminRole.SUPER_ADMIN : AdminRole.ADMIN;
        return AdminSummaryResponse.of(team.changeRole(me, AdminId.parse(adminId), role), me, zone);
    }

    record ChangeRoleRequest(
            @NotBlank(message = "Choose admin or super admin.")
            @Pattern(regexp = "admin|superAdmin", message = "Choose admin or super admin.") String role) {
    }

    /** {@code superAdmin} or {@code admin}, as the panel names them. */
    static String roleName(AdminRole role) {
        return role == AdminRole.SUPER_ADMIN ? "superAdmin" : "admin";
    }

    /** @param role {@code admin} (when left out) or {@code superAdmin} */
    record AddAdminRequest(
            @NotBlank(message = "Enter their name.")
            @Size(max = Admin.MAX_NAME_LENGTH, message = "Keep the name to 80 characters.") String name,
            @NotBlank(message = "Enter their email address.")
            @Size(max = EmailAddress.MAX_LENGTH, message = "Enter a valid email address.") String email,
            @Pattern(regexp = "admin|superAdmin", message = "Choose admin or super admin.") String role) {
    }

    /**
     * @param role     {@code superAdmin} or {@code admin}
     * @param addedAt  in Pin's time zone, without an offset
     * @param addedBy  the name of the admin who added them; null when added from the server settings
     * @param password {@code own}, {@code temporary} (must choose their own at sign-in) or {@code none}
     */
    record AdminSummaryResponse(String id, String name, String email, String role, LocalDateTime addedAt,
                                String addedBy, String password, boolean you) {

        static AdminSummaryResponse of(AdminSummary admin, Admin me, ZoneId zone) {
            return new AdminSummaryResponse(admin.id().toString(), admin.name(), admin.email().value(),
                    roleName(admin.role()), LocalDateTime.ofInstant(admin.addedAt(), zone),
                    admin.addedByIfKnown().orElse(null), admin.password().name().toLowerCase(Locale.ROOT),
                    admin.id().equals(me.id()));
        }
    }

    record AddedAdminResponse(String id, String name, String email, String role, String temporaryPassword) {
    }
}
