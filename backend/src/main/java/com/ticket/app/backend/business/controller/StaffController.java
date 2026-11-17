package com.ticket.app.backend.business.controller;

import java.util.List;

import com.ticket.app.backend.business.service.BusinessService;
import com.ticket.app.backend.business.model.StaffId;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.business.model.Team;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The owner's Staff screen: the team, removing scanners, and the join code.
 * Joining itself is {@code POST /merchant/staff/join}, part of sign-up.
 */
@RestController
@RequestMapping("/merchant/staff")
@PreAuthorize("hasRole('OWNER')")
class StaffController {

    private final BusinessService business;

    StaffController(BusinessService business) {
        this.business = business;
    }

    /** {@code {"joinCode": "482913", "members": [{"id", "name", "role"}]}}, the owner first. */
    @GetMapping
    TeamResponse team(@AuthenticationPrincipal StaffMember me) {
        return TeamResponse.of(business.team(me));
    }

    /** Takes a scanner off the team; they are signed out on their next request. */
    @DeleteMapping("/{staffId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void remove(@AuthenticationPrincipal StaffMember me, @PathVariable String staffId) {
        business.removeMember(me, StaffId.parse(staffId));
    }

    /** A new join code. The old one stops working at once. */
    @PostMapping("/join-code")
    JoinCodeResponse newJoinCode(@AuthenticationPrincipal StaffMember me) {
        return new JoinCodeResponse(business.newJoinCode(me).digits());
    }

    record TeamResponse(String joinCode, List<MemberResponse> members) {

        static TeamResponse of(Team team) {
            return new TeamResponse(team.business().joinCode().digits(),
                    team.members().stream().map(MemberResponse::of).toList());
        }
    }

    record MemberResponse(String id, String name, String role) {

        static MemberResponse of(StaffMember member) {
            return new MemberResponse(member.id().toString(), member.name(), member.role().code());
        }
    }

    record JoinCodeResponse(String joinCode) {
    }
}
