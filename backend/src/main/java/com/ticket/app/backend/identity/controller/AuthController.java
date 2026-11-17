package com.ticket.app.backend.identity.controller;

import com.ticket.app.backend.business.model.BusinessType;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.identity.service.BuyerSessionService;
import com.ticket.app.backend.identity.service.SessionService;
import com.ticket.app.backend.identity.service.SignInApp;
import com.ticket.app.backend.identity.service.SignInService;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.identity.config.SessionAuthenticationFilter;
import com.ticket.app.backend.identity.dto.JoinTeamRequest;
import com.ticket.app.backend.identity.dto.OtpRequest;
import com.ticket.app.backend.identity.dto.RegisterBusinessRequest;
import com.ticket.app.backend.identity.dto.SessionResponse;
import com.ticket.app.backend.identity.dto.UserResponse;
import com.ticket.app.backend.identity.dto.VerifyRequest;
import com.ticket.app.backend.identity.dto.VerifyResponse;

/**
 * Sign-in by phone number and code, and account creation for new numbers.
 * Paths follow the developer handoff; {@code POST /merchant/businesses},
 * {@code POST /auth/sign-out} and {@code GET /me} are additions to it.
 */
@RestController
class AuthController {

    private final SignInService signIn;
    private final SessionService sessions;
    private final BuyerSessionService buyerSessions;

    AuthController(SignInService signIn, SessionService sessions, BuyerSessionService buyerSessions) {
        this.signIn = signIn;
        this.sessions = sessions;
        this.buyerSessions = buyerSessions;
    }

    /** Texts a 6-digit code to the number. */
    @PostMapping("/auth/otp")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void sendCode(@Valid @RequestBody OtpRequest request) {
        signIn.sendCode(request.phone());
    }

    /**
     * {@code {"session": ...}} for a number with an account in the app named by
     * {@code app} (merchant when left out), {@code {"registrationToken": "..."}} for a new one.
     */
    @PostMapping("/auth/verify")
    VerifyResponse verify(@Valid @RequestBody VerifyRequest request) {
        return VerifyResponse.of(signIn.verify(request.phone(), request.code(), SignInApp.fromCode(request.app())));
    }

    /** A new number registers a business and becomes its owner. */
    @PostMapping("/merchant/businesses")
    @ResponseStatus(HttpStatus.CREATED)
    SessionResponse registerBusiness(@Valid @RequestBody RegisterBusinessRequest request) {
        return SessionResponse.of(signIn.registerBusiness(request.registrationToken(), request.businessName(),
                BusinessType.fromCode(request.type()), request.contactName()));
    }

    /** A new number joins a business as a scanner with the business's join code. */
    @PostMapping("/merchant/staff/join")
    @ResponseStatus(HttpStatus.CREATED)
    SessionResponse joinTeam(@Valid @RequestBody JoinTeamRequest request) {
        return SessionResponse.of(signIn.joinTeam(request.registrationToken(), request.name(), request.joinCode()));
    }

    /**
     * Ends this device's session; its token stops working. The token belongs to a member
     * or a buyer, and removing a token that is not in one of the tables changes nothing.
     */
    @PostMapping("/auth/sign-out")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void signOut(@RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        SessionAuthenticationFilter.bearerToken(authorization).ifPresent(token -> {
            sessions.end(token);
            buyerSessions.end(token);
        });
    }

    /** Who is signed in. The app can use it to check a saved session still works. */
    @GetMapping("/me")
    UserResponse me(@AuthenticationPrincipal StaffMember me) {
        return UserResponse.of(me);
    }
}
