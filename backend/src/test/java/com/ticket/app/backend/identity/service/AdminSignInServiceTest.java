package com.ticket.app.backend.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import java.time.Clock;
import java.util.Map;

import com.ticket.app.backend.admin.service.AdminDirectory;
import com.ticket.app.backend.identity.repository.AdminPasswordRepository;
import com.ticket.app.backend.identity.model.PasswordHasher;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;

class AdminSignInServiceTest {

    private final AdminDirectory admins = mock(AdminDirectory.class);
    private final AdminPasswordRepository passwords = mock(AdminPasswordRepository.class);
    private final AdminSessionService sessions = mock(AdminSessionService.class);

    @Test
    void outsideDevelopmentForgotPasswordIsRefusedAndChangesNothing() {
        AdminSignInService service = new AdminSignInService(admins, passwords, mock(PasswordHasher.class), sessions,
                Clock.systemUTC(), settingsOfAServerWithoutPinSettings());

        assertThat(service.canResetPasswordsWithoutProof()).isFalse();
        assertThatThrownBy(() -> service.resetPasswordWithoutProof("moniroth@pin.example", "a long new password"))
                .isInstanceOf(BusinessRuleException.class)
                .hasMessage("Passwords can only be reset here on a development server. "
                        + "Ask Pin's tech team to set a new one.");
        verifyNoInteractions(admins, passwords, sessions);
    }

    /** The defaults, as a production server has them unless told otherwise. */
    private static PinProperties settingsOfAServerWithoutPinSettings() {
        return new Binder(new MapConfigurationPropertySource(Map.of())).bindOrCreate("pin", PinProperties.class);
    }
}
