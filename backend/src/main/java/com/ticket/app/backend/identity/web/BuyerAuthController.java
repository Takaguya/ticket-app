package com.ticket.app.backend.identity.web;

import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.identity.application.SignInService;
import com.ticket.app.backend.identity.web.AuthDtos.BuyerResponse;
import com.ticket.app.backend.identity.web.AuthDtos.BuyerSessionResponse;
import com.ticket.app.backend.identity.web.AuthDtos.RegisterBuyerRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Buyer accounts for the user app. Signing in is {@code POST /auth/otp} and
 * {@code POST /auth/verify} with {@code app=user}; a new number then registers here.
 */
@RestController
@RequestMapping("/buyer")
class BuyerAuthController {

    private final SignInService signIn;

    BuyerAuthController(SignInService signIn) {
        this.signIn = signIn;
    }

    /** A new number registers as a buyer and is signed in. */
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    BuyerSessionResponse register(@Valid @RequestBody RegisterBuyerRequest request) {
        return BuyerSessionResponse.of(signIn.registerBuyer(request.registrationToken(), request.name(),
                Gender.fromCode(request.gender()), request.dateOfBirth(), request.email()));
    }

    /** Who is signed in. The app can use it to check a saved session still works. */
    @GetMapping("/me")
    BuyerResponse me(@AuthenticationPrincipal Buyer me) {
        return BuyerResponse.of(me);
    }
}
