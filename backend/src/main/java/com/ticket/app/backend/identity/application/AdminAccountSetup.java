package com.ticket.app.backend.identity.application;

import java.util.Optional;

import com.ticket.app.backend.admin.application.AdminDirectory;
import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.identity.domain.AdminPassword;
import com.ticket.app.backend.identity.domain.AdminPasswordRepository;
import com.ticket.app.backend.identity.domain.PasswordHasher;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import com.ticket.app.backend.shared.domain.EmailAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Applies {@code pin.admin-account} on startup: creates the admin with that email
 * address if there is none, and gives them that password if it is not theirs yet.
 * This is how the first admin is added, and how a forgotten password is replaced:
 * set the two settings and restart. Wrong settings stop the server from starting.
 */
@Component
public class AdminAccountSetup implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminAccountSetup.class);

    private final AdminDirectory admins;
    private final AdminPasswordRepository passwords;
    private final PasswordHasher hasher;
    private final PinProperties properties;

    public AdminAccountSetup(AdminDirectory admins, AdminPasswordRepository passwords, PasswordHasher hasher,
                             PinProperties properties) {
        this.admins = admins;
        this.passwords = passwords;
        this.hasher = hasher;
        this.properties = properties;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        PinProperties.AdminAccount account = properties.adminAccount();
        if (!account.isSet()) {
            // The demo data adds its own admin.
            if (!properties.demoData() && passwords.count() == 0) {
                log.warn("Nobody can sign in to the admin panel. Set pin.admin-account.email and "
                        + "pin.admin-account.password (PIN_ADMINACCOUNT_EMAIL, PIN_ADMINACCOUNT_PASSWORD) and restart.");
            }
            return;
        }
        if (account.password() == null || account.password().isBlank()) {
            throw new IllegalStateException(
                    "pin.admin-account.email is set without pin.admin-account.password. Set both, or remove both.");
        }
        try {
            apply(EmailAddress.of(account.email()), account.password(), account.name());
        } catch (BusinessRuleException e) {
            throw new IllegalStateException("pin.admin-account: " + e.getMessage(), e);
        }
    }

    private void apply(EmailAddress email, String password, String name) {
        AdminPassword.requireAllowed(password);
        Optional<Admin> existing = admins.findByEmail(email);
        Admin admin = existing.orElseGet(() -> admins.add(name, email));
        if (existing.isEmpty()) {
            log.info("Added admin {}", email);
        }

        Optional<AdminPassword> current = passwords.findAndLock(admin.id());
        if (current.isPresent() && current.get().matches(password, hasher)) {
            return;
        }
        passwords.save(AdminPassword.set(admin.id(), password, hasher));
        log.info("{} the password of admin {}. The pin.admin-account settings can be removed now.",
                current.isPresent() ? "Changed" : "Set", email);
    }
}
