package com.ticket.app.backend.identity.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import com.ticket.app.backend.admin.domain.AdminId;
import com.ticket.app.backend.shared.domain.BusinessRuleException;
import org.junit.jupiter.api.Test;

class AdminPasswordTest {

    /** Not a real hash: these tests are about the counting, not the hashing. */
    private static final PasswordHasher HASHER = new PasswordHasher() {
        @Override
        public String hash(String password) {
            return "hashed:" + password;
        }

        @Override
        public boolean matches(String password, String hash) {
            return hash.equals("hashed:" + password);
        }
    };

    private static final AdminId ADMIN = new AdminId(UUID.fromString("40000000-0000-7000-8000-000000000001"));
    private static final String RIGHT = "the right password";
    private static final Instant NOW = Instant.parse("2026-11-14T02:00:00Z");
    private static final Duration LOCK_FOR = Duration.ofMinutes(15);

    private final AdminPassword password = AdminPassword.set(ADMIN, RIGHT, HASHER);

    @Test
    void onlyAHashIsKept() {
        assertThat(password.hash()).isEqualTo("hashed:" + RIGHT);
        assertThat(password.matches(RIGHT, HASHER)).isTrue();
        assertThat(password.matches("another password", HASHER)).isFalse();
    }

    @Test
    void theRightPasswordIsCorrectAndStartsTheCountAgain() {
        check("wrong password 1");
        check("wrong password 2");

        assertThat(check(RIGHT)).isEqualTo(AdminPassword.Check.CORRECT);
        assertThat(password.wrongAttempts()).isZero();
    }

    @Test
    void theFifthWrongPasswordInARowLocksSignInEvenForTheRightPassword() {
        for (int wrong = 1; wrong < 5; wrong++) {
            assertThat(check("wrong password " + wrong)).isEqualTo(AdminPassword.Check.WRONG);
            assertThat(password.wrongAttempts()).isEqualTo(wrong);
        }

        assertThat(check("wrong password 5")).isEqualTo(AdminPassword.Check.LOCKED);
        assertThat(password.lockedUntil()).contains(NOW.plus(LOCK_FOR));
        assertThat(password.check(RIGHT, HASHER, NOW.plus(LOCK_FOR).minusSeconds(1), 5, LOCK_FOR))
                .isEqualTo(AdminPassword.Check.LOCKED);
    }

    @Test
    void afterTheLockTheRightPasswordWorksAgain() {
        for (int wrong = 1; wrong <= 5; wrong++) {
            check("wrong password " + wrong);
        }

        assertThat(password.check(RIGHT, HASHER, NOW.plus(LOCK_FOR), 5, LOCK_FOR))
                .isEqualTo(AdminPassword.Check.CORRECT);
        assertThat(password.lockedUntil()).isEmpty();
    }

    @Test
    void aNewPasswordLiftsTheLock() {
        for (int wrong = 1; wrong <= 5; wrong++) {
            check("wrong password " + wrong);
        }

        AdminPassword replaced = AdminPassword.set(ADMIN, "a brand new password", HASHER);

        assertThat(replaced.isLockedAt(NOW)).isFalse();
        assertThat(replaced.wrongAttempts()).isZero();
    }

    @Test
    void passwordsNeedTwelveCharactersAndFitInTheHash() {
        assertThatThrownBy(() -> AdminPassword.set(ADMIN, "eleven char", HASHER))
                .isInstanceOf(BusinessRuleException.class)
                .hasMessage("A password needs at least 12 characters.");
        assertThat(AdminPassword.set(ADMIN, "twelve chars", HASHER).hash()).isEqualTo("hashed:twelve chars");

        assertThat(AdminPassword.set(ADMIN, "x".repeat(72), HASHER)).isNotNull();
        assertThatThrownBy(() -> AdminPassword.set(ADMIN, "x".repeat(73), HASHER))
                .isInstanceOf(BusinessRuleException.class);
        // 25 Khmer letters are 75 bytes.
        assertThatThrownBy(() -> AdminPassword.set(ADMIN, "ក".repeat(25), HASHER))
                .isInstanceOf(BusinessRuleException.class);
    }

    @Test
    void aTemporaryPasswordSignsInButMustBeReplacedByTheAdminsOwn() {
        AdminPassword temporary = AdminPassword.temporary(ADMIN, "k7mp-x3qa-9fzt-h2wd", HASHER);

        assertThat(temporary.mustChange()).isTrue();
        assertThat(temporary.check("k7mp-x3qa-9fzt-h2wd", HASHER, NOW, 5, LOCK_FOR))
                .isEqualTo(AdminPassword.Check.CORRECT);
        assertThat(AdminPassword.set(ADMIN, "my very own password", HASHER).mustChange()).isFalse();
    }

    @Test
    void temporaryPasswordsAreRandomEasyToReadAndAllowed() {
        Set<String> made = new HashSet<>();
        for (int i = 0; i < 200; i++) {
            String password = AdminPassword.newTemporaryPassword();
            assertThat(password).matches("[a-hjkmnp-z2-9]{4}(-[a-hjkmnp-z2-9]{4}){3}");
            AdminPassword.requireAllowed(password);
            made.add(password);
        }
        assertThat(made).hasSize(200);
    }

    private AdminPassword.Check check(String typed) {
        return password.check(typed, HASHER, NOW, 5, LOCK_FOR);
    }
}
