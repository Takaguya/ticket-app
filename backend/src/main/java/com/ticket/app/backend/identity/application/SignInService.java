package com.ticket.app.backend.identity.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

import com.ticket.app.backend.business.application.BusinessService;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.business.domain.JoinCode;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.buyer.application.BuyerService;
import com.ticket.app.backend.buyer.domain.Buyer;
import com.ticket.app.backend.buyer.domain.Gender;
import com.ticket.app.backend.identity.domain.OtpChallenge;
import com.ticket.app.backend.identity.domain.OtpChallengeRepository;
import com.ticket.app.backend.identity.domain.RegistrationToken;
import com.ticket.app.backend.identity.domain.RegistrationTokenRepository;
import com.ticket.app.backend.identity.domain.SignInException;
import com.ticket.app.backend.identity.domain.SmsSender;
import com.ticket.app.backend.identity.domain.TokenHash;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.DomainException;
import com.ticket.app.backend.shared.domain.PhoneNumber;
import com.ticket.app.backend.shared.domain.Secrets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Signing in with a phone number and a texted code, and the ways a new number gets an
 * account: in the merchant app by registering a business or joining one with its join
 * code, in the user app by registering as a buyer. Pin's admins sign in with an email
 * and password instead ({@link AdminSignInService}).
 */
@Service
public class SignInService {

    private static final Logger log = LoggerFactory.getLogger(SignInService.class);

    private final OtpChallengeRepository challenges;
    private final RegistrationTokenRepository registrations;
    private final SessionService sessions;
    private final BuyerSessionService buyerSessions;
    private final BusinessService business;
    private final BuyerService buyers;
    private final SmsSender sms;
    private final Clock clock;
    private final PinProperties properties;
    private final PinProperties.Otp otp;

    public SignInService(OtpChallengeRepository challenges, RegistrationTokenRepository registrations,
                         SessionService sessions, BuyerSessionService buyerSessions, BusinessService business,
                         BuyerService buyers, SmsSender sms, Clock clock, PinProperties properties) {
        this.challenges = challenges;
        this.registrations = registrations;
        this.sessions = sessions;
        this.buyerSessions = buyerSessions;
        this.business = business;
        this.buyers = buyers;
        this.sms = sms;
        this.clock = clock;
        this.properties = properties;
        this.otp = properties.otp();
        if (otp.usesDevCode()) {
            log.warn("Every sign-in code is the development code and no SMS is sent. "
                    + "Never run like this in production.");
        }
    }

    /**
     * Texts a new code to the number. It replaces any earlier code. A number can ask
     * again after 30 seconds, and be sent a few codes an hour.
     */
    @Transactional
    public void sendCode(String phoneNumber) {
        PhoneNumber phone = PhoneNumber.of(phoneNumber);
        Instant now = clock.instant();
        String code = otp.usesDevCode() ? otp.devCode() : Secrets.digits(6);

        Optional<OtpChallenge> current = challenges.findAndLock(phone);
        if (current.isPresent()) {
            switch (current.get().resendCheck(now, otp.resendAfter(), otp.maxSendsPerHour())) {
                case TOO_SOON -> throw tooSoon();
                case HOURLY_LIMIT -> throw BusinessRuleException.tooSoon(
                        "Too many codes were sent to this number. Please try again in an hour.");
                case ALLOWED -> challenges.update(current.get().resend(code, now, otp.ttl()));
            }
        } else if (!challenges.tryAdd(OtpChallenge.send(phone, code, now, otp.ttl()))) {
            // Another request for the same new number got in first.
            throw tooSoon();
        }

        if (!otp.usesDevCode()) {
            sms.send(phone, "Your Pin code is " + code + ". It expires in " + otp.ttl().toMinutes() + " minutes.");
        }
    }

    /**
     * Checks the code. A number with an account in that app is signed in; a new number
     * gets a registration token. Refusals do not roll back, so a wrong guess stays counted.
     */
    @Transactional(noRollbackFor = DomainException.class)
    public VerifyResult verify(String phoneNumber, String code, SignInApp app) {
        PhoneNumber phone = PhoneNumber.of(phoneNumber);
        confirmCode(phone, code);
        return switch (app) {
            case MERCHANT -> business.currentMemberWithPhone(phone)
                    .<VerifyResult>map(sessions::start)
                    .orElseGet(() -> newNumber(phone, clock.instant()));
            case USER -> buyers.withPhone(phone)
                    .<VerifyResult>map(buyerSessions::start)
                    .orElseGet(() -> newNumber(phone, clock.instant()));
        };
    }

    /**
     * Creates the buyer's account with the confirmed number, and signs them in. A refused
     * detail (a missing name, a bad email) leaves the token usable, so the person can fix
     * it and send again.
     */
    @Transactional
    public BuyerSignedIn registerBuyer(String registrationToken, String name, Gender gender, LocalDate dateOfBirth,
                                       String email) {
        RegistrationToken registration = usableRegistration(registrationToken);
        Buyer buyer = buyers.register(registration.phone(), name, gender, dateOfBirth, email);
        registrations.remove(registration.tokenHash());
        return buyerSessions.start(buyer);
    }

    /** Creates the business with the confirmed number as its owner, and signs them in. */
    @Transactional
    public SignedIn registerBusiness(String registrationToken, String businessName, BusinessType type,
                                     String contactName) {
        RegistrationToken registration = usableRegistration(registrationToken);
        registrations.remove(registration.tokenHash());
        StaffMember owner = business.registerBusiness(businessName, type, contactName, registration.phone());
        return sessions.start(owner);
    }

    /**
     * Adds the confirmed number as a scanner of the business whose join code this is,
     * and signs them in. After a wrong code the token still works, up to
     * {@link RegistrationToken#MAX_WRONG_JOIN_CODES} wrong codes. Refusals do not roll
     * back, so wrong codes stay counted.
     */
    @Transactional(noRollbackFor = DomainException.class)
    public SignedIn joinTeam(String registrationToken, String name, String joinCode) {
        RegistrationToken registration = usableRegistration(registrationToken);
        Optional<StaffMember> scanner = JoinCode.parse(joinCode)
                .flatMap(code -> business.joinAsScanner(code, name, registration.phone()));

        if (scanner.isEmpty()) {
            if (registration.recordWrongJoinCode()) {
                registrations.update(registration);
                throw BusinessRuleException.invalid("That join code is not right. Ask the owner for the current code.");
            }
            registrations.remove(registration.tokenHash());
            throw SignInException.registrationExpired("Too many wrong join codes. Please confirm your phone number again.");
        }

        registrations.remove(registration.tokenHash());
        return sessions.start(scanner.get());
    }

    /** Uses up the code if it is right; counts a wrong guess against it otherwise. */
    private void confirmCode(PhoneNumber phone, String code) {
        OtpChallenge challenge = challenges.findAndLock(phone).orElseThrow(SignInException::invalidCode);
        switch (challenge.check(code, clock.instant(), otp.maxAttempts())) {
            case CORRECT -> challenges.remove(phone);
            case WRONG -> {
                challenges.update(challenge);
                throw SignInException.invalidCode();
            }
            case UNUSABLE -> throw SignInException.invalidCode();
        }
    }

    private VerifyResult newNumber(PhoneNumber phone, Instant now) {
        registrations.removeAllFor(phone);
        RegistrationToken.Issued issued = RegistrationToken.issue(phone, now, properties.registrationTtl());
        registrations.add(issued.registration());
        return new VerifyResult.NewNumber(issued.token());
    }

    private RegistrationToken usableRegistration(String token) {
        return registrations.findAndLock(TokenHash.of(token))
                .filter(registration -> registration.isUsableAt(clock.instant()))
                .orElseThrow(() -> SignInException.registrationExpired("Please confirm your phone number again."));
    }

    private static BusinessRuleException tooSoon() {
        return BusinessRuleException.tooSoon("Please wait a moment before asking for another code.");
    }
}
