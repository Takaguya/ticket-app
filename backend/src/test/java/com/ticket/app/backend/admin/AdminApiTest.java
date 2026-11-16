package com.ticket.app.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import com.ticket.app.backend.ApiTest;
import com.ticket.app.backend.shared.domain.Ids;
import com.ticket.app.backend.shared.domain.Money;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * The admin panel's API: who may use it, its lists, and how approving, suspending
 * and paying a business changes what the merchant app can do.
 */
class AdminApiTest extends ApiTest {

    @Autowired
    private JdbcClient jdbc;

    private static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));
    private static final String LEGEND_CINEMA = "10000000-0000-7000-8000-000000000003";
    private static final String LEGEND_CINEMA_OWNER = "+85515300418";
    private static final String MARATHON = "30000000-0000-7000-8000-000000000001";

    /** The password newly added admins choose in these tests. */
    private static final String OWN_PASSWORD = "an own password 123";

    @Test
    void anAdminSignsInWithTheirEmailAndPassword() {
        get("/admin/me", adminToken()).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Moniroth Prak")
                .jsonPath("$.email").isEqualTo(ADMIN_EMAIL);

        // However the address is typed.
        adminSignIn("  Moniroth@PIN.Example ", ADMIN_PASSWORD).expectStatus().isOk()
                .expectBody().jsonPath("$.admin.email").isEqualTo(ADMIN_EMAIL);

        adminSignIn("moniroth", ADMIN_PASSWORD).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter a valid email address.");
        post("/admin/auth/sign-in", Map.of("email", ADMIN_EMAIL)).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter your password.");
    }

    @Test
    void anAdminAddedOnStartupSignsInAndTooManyWrongPasswordsLockThem() {
        adminSignIn(SETUP_ADMIN_EMAIL, SETUP_ADMIN_PASSWORD).expectStatus().isOk()
                .expectBody().jsonPath("$.admin.name").isEqualTo("Setup Admin");

        // An address that is nobody's gets the same answer as a wrong password.
        expectWrongEmailOrPassword(adminSignIn("nobody@pin.example", SETUP_ADMIN_PASSWORD));
        for (int wrong = 1; wrong < 5; wrong++) {
            expectWrongEmailOrPassword(adminSignIn(SETUP_ADMIN_EMAIL, "not-the-password-" + wrong));
        }
        adminSignIn(SETUP_ADMIN_EMAIL, "not-the-password-5").expectStatus().isEqualTo(429)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Too many wrong passwords. Please try again in 15 minutes.");
        // Even the right password, until the lock ends.
        adminSignIn(SETUP_ADMIN_EMAIL, SETUP_ADMIN_PASSWORD).expectStatus().isEqualTo(429);
    }

    @Test
    void onADevelopmentServerForgotPasswordSetsANewOneAndSignsTheAdminOutEverywhere() {
        String email = "forgetful@pin.example";
        jdbc.sql("insert into admins (id, email, name) values (:id, :email, 'Forgetful Admin')")
                .param("id", Ids.newId())
                .param("email", email)
                .update();
        http.get().uri("/admin/auth/password-reset").exchange().expectStatus().isOk()
                .expectBody().jsonPath("$.available").isEqualTo(true);

        post("/admin/auth/password-reset", Map.of("email", email, "newPassword", "too short"))
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("A password needs at least 12 characters.");
        post("/admin/auth/password-reset", Map.of("email", "nobody@pin.example", "newPassword", "first new password"))
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("No Pin admin has this email address.");

        post("/admin/auth/password-reset", Map.of("email", email, "newPassword", "first new password"))
                .expectStatus().isNoContent();
        String earlierSession = read(adminSignIn(email, "first new password").expectStatus().isOk().expectBody(),
                "$.accessToken");

        post("/admin/auth/password-reset", Map.of("email", email, "newPassword", "second new password"))
                .expectStatus().isNoContent();
        get("/admin/me", earlierSession).expectStatus().isUnauthorized();
        expectWrongEmailOrPassword(adminSignIn(email, "first new password"));
        adminSignIn(email, "second new password").expectStatus().isOk();
    }

    @Test
    void aSignedInAdminChangesTheirPasswordAndTheirOtherBrowsersAreSignedOut() {
        String email = "changing@pin.example";
        addAdmin(email, "first password 1");
        String here = read(adminSignIn(email, "first password 1").expectStatus().isOk().expectBody(), "$.accessToken");
        String elsewhere = read(adminSignIn(email, "first password 1").expectStatus().isOk().expectBody(),
                "$.accessToken");

        changePassword(here, "not my password", "second password 2").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Your current password is wrong.");
        changePassword(here, "first password 1", "too short").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("A password needs at least 12 characters.");
        changePassword(here, "first password 1", "first password 1").expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose a new password, not your current one.");

        changePassword(here, "first password 1", "second password 2").expectStatus().isNoContent();
        get("/admin/me", here).expectStatus().isOk();
        get("/admin/me", elsewhere).expectStatus().isUnauthorized();
        expectWrongEmailOrPassword(adminSignIn(email, "first password 1"));
        adminSignIn(email, "second password 2").expectStatus().isOk();

        post("/admin/me/password", Map.of("currentPassword", "x", "newPassword", "a long new password"),
                accessTokenFor(OWNER)).expectStatus().isForbidden();
    }

    @Test
    void anAdminAddsAnotherWhoMustChooseTheirOwnPasswordFirst() {
        String admin = adminToken();
        String added = json(post("/admin/admins", Map.of("name", "Sokha Chan", "email", " Sokha@PIN.example "), admin)
                .expectStatus().isCreated());
        assertThat(JsonPath.<String>read(added, "$.email")).isEqualTo("sokha@pin.example");
        String temporary = JsonPath.read(added, "$.temporaryPassword");
        assertThat(temporary).matches("[a-z2-9]{4}(-[a-z2-9]{4}){3}");

        post("/admin/admins", Map.of("name", "Someone Else", "email", "sokha@pin.example"), admin)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("sokha@pin.example is already a Pin admin.");
        post("/admin/admins", Map.of("name", " ", "email", "nameless@pin.example"), admin)
                .expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Enter their name.");

        String list = json(get("/admin/admins", admin).expectStatus().isOk());
        assertThat(field(list, "Sokha Chan", "password")).isEqualTo("temporary");
        assertThat(field(list, "Sokha Chan", "addedBy")).isEqualTo("Moniroth Prak");
        assertThat(field(list, "Sokha Chan", "you")).isEqualTo("false");
        assertThat(field(list, "Moniroth Prak", "password")).isEqualTo("own");
        assertThat(field(list, "Moniroth Prak", "you")).isEqualTo("true");

        // The temporary password signs in, but only to choose their own.
        String sokha = read(adminSignIn("sokha@pin.example", temporary).expectStatus().isOk()
                .expectBody().jsonPath("$.admin.mustChangePassword").isEqualTo(true), "$.accessToken");
        get("/admin/merchants", sokha).expectStatus().isForbidden()
                .expectBody()
                .jsonPath("$.code").isEqualTo("password_change_required")
                .jsonPath("$.message").isEqualTo("Choose your own password first.");
        post("/admin/admins", Map.of("name", "Sneaky", "email", "sneaky@pin.example"), sokha)
                .expectStatus().isForbidden();
        get("/admin/me", sokha).expectStatus().isOk()
                .expectBody().jsonPath("$.mustChangePassword").isEqualTo(true);

        changePassword(sokha, temporary, "sokha's own password").expectStatus().isNoContent();
        get("/admin/me", sokha).expectStatus().isOk()
                .expectBody().jsonPath("$.mustChangePassword").isEqualTo(false);
        get("/admin/merchants", sokha).expectStatus().isOk();
        assertThat(field(json(get("/admin/admins", admin).expectStatus().isOk()), "Sokha Chan", "password"))
                .isEqualTo("own");
    }

    @Test
    void onlySuperAdminsAddAndRemoveAdmins() {
        String superAdmin = adminToken();
        String monirothId = read(get("/admin/me", superAdmin).expectStatus().isOk()
                .expectBody().jsonPath("$.role").isEqualTo("superAdmin"), "$.id");

        String plainAdded = json(post("/admin/admins", Map.of("name", "Plain Admin", "email", "plain@pin.example"),
                superAdmin).expectStatus().isCreated());
        assertThat(JsonPath.<String>read(plainAdded, "$.role")).isEqualTo("admin");
        String plainId = JsonPath.read(plainAdded, "$.id");
        String plain = firstSignIn("plain@pin.example", JsonPath.read(plainAdded, "$.temporaryPassword"));

        // An admin does everything else, and sees the list, but cannot add or remove admins.
        get("/admin/me", plain).expectStatus().isOk().expectBody().jsonPath("$.role").isEqualTo("admin");
        get("/admin/merchants", plain).expectStatus().isOk();
        get("/admin/admins", plain).expectStatus().isOk();
        post("/admin/admins", Map.of("name", "Sneaky", "email", "sneaky.plain@pin.example"), plain)
                .expectStatus().isForbidden()
                .expectBody().jsonPath("$.message").isEqualTo("Only super admins can manage admins.");
        post("/admin/admins/" + monirothId + "/remove", Map.of(), plain).expectStatus().isForbidden();

        // A super admin can add another super admin.
        post("/admin/admins", Map.of("name", "Second Super", "email", "second.super@pin.example", "role", "superAdmin"),
                superAdmin).expectStatus().isCreated();
        assertThat(field(json(get("/admin/admins", superAdmin).expectStatus().isOk()), "Second Super", "role"))
                .isEqualTo("superAdmin");
        post("/admin/admins", Map.of("name", "Owner?", "email", "owner.role@pin.example", "role", "owner"),
                superAdmin).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Choose admin or super admin.");

        post("/admin/admins/" + monirothId + "/remove", Map.of(), superAdmin).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("You can't remove yourself. Ask another super admin.");

        // Removing signs the admin out at once, and they can no longer sign in.
        post("/admin/admins/" + plainId + "/remove", Map.of(), superAdmin).expectStatus().isNoContent();
        get("/admin/me", plain).expectStatus().isUnauthorized();
        expectWrongEmailOrPassword(adminSignIn("plain@pin.example", OWN_PASSWORD));
        assertThat(JsonPath.<List<String>>read(json(get("/admin/admins", superAdmin).expectStatus().isOk()),
                "$[*].email")).doesNotContain("plain@pin.example");
        post("/admin/admins/" + plainId + "/remove", Map.of(), superAdmin).expectStatus().isNotFound();
        post("/admin/admins/not-an-id/remove", Map.of(), superAdmin).expectStatus().isNotFound();

        // The address can be given to a new admin.
        post("/admin/admins", Map.of("name", "Plain Admin Again", "email", "plain@pin.example"), superAdmin)
                .expectStatus().isCreated();
    }

    @Test
    void aSuperAdminChangesAnotherAdminsRole() {
        String superAdmin = adminToken();
        String monirothId = read(get("/admin/me", superAdmin).expectStatus().isOk().expectBody(), "$.id");
        String added = json(post("/admin/admins", Map.of("name", "Rising Admin", "email", "rising@pin.example"),
                superAdmin).expectStatus().isCreated());
        String risingId = JsonPath.read(added, "$.id");
        String rising = firstSignIn("rising@pin.example", JsonPath.read(added, "$.temporaryPassword"));
        post("/admin/admins/" + monirothId + "/role", Map.of("role", "admin"), rising).expectStatus().isForbidden()
                .expectBody().jsonPath("$.message").isEqualTo("Only super admins can manage admins.");

        post("/admin/admins/" + risingId + "/role", Map.of("role", "superAdmin"), superAdmin).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Rising Admin")
                .jsonPath("$.role").isEqualTo("superAdmin");
        // From their next request, without signing in again.
        get("/admin/me", rising).expectStatus().isOk().expectBody().jsonPath("$.role").isEqualTo("superAdmin");
        post("/admin/admins", Map.of("name", "Their Pick", "email", "their.pick@pin.example"), rising)
                .expectStatus().isCreated();

        post("/admin/admins/" + risingId + "/role", Map.of("role", "admin"), superAdmin).expectStatus().isOk();
        get("/admin/me", rising).expectStatus().isOk().expectBody().jsonPath("$.role").isEqualTo("admin");

        post("/admin/admins/" + monirothId + "/role", Map.of("role", "admin"), superAdmin).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("You can't change your own role. Ask another super admin.");
        post("/admin/admins/" + risingId + "/role", Map.of("role", "owner"), superAdmin).expectStatus().isBadRequest();
        post("/admin/admins/" + UUID.randomUUID() + "/role", Map.of("role", "admin"), superAdmin)
                .expectStatus().isNotFound();
    }

    @Test
    void anAdminSeesTheirOwnProfile() {
        get("/admin/me/profile", adminToken()).expectStatus().isOk()
                .expectBody()
                .jsonPath("$.name").isEqualTo("Moniroth Prak")
                .jsonPath("$.email").isEqualTo(ADMIN_EMAIL)
                .jsonPath("$.role").isEqualTo("superAdmin")
                .jsonPath("$.password").isEqualTo("own")
                .jsonPath("$.you").isEqualTo(true);
    }

    @Test
    void merchantAndAdminSessionsNeverOpenEachOthersEndpoints() {
        get("/admin/merchants", accessTokenFor(OWNER)).expectStatus().isForbidden()
                .expectBody().jsonPath("$.message").isEqualTo("Only Pin admins can do this.");
        post("/admin/merchants/" + LEGEND_CINEMA + "/suspend", Map.of(), accessTokenFor(OWNER))
                .expectStatus().isForbidden();
        get("/merchant/events", adminToken()).expectStatus().isForbidden()
                .expectBody().jsonPath("$.message").isEqualTo("Sign in with Pin Merchant to do this.");
        get("/me", adminToken()).expectStatus().isForbidden();
        http.get().uri("/admin/merchants").exchange().expectStatus().isUnauthorized();
        get("/admin/merchants", "not-a-session").expectStatus().isUnauthorized();
    }

    @Test
    void theListsCoverEveryBusiness() {
        String admin = adminToken();

        String overview = json(get("/admin/overview", admin).expectStatus().isOk());
        assertThat(JsonPath.<String>read(overview, "$.period.from")).isEqualTo(TODAY.withDayOfMonth(1).toString());
        assertThat(JsonPath.<String>read(overview, "$.period.to")).isEqualTo(TODAY.toString());
        assertThat(JsonPath.<Double>read(overview, "$.commissionRate")).isEqualTo(5.0);

        String merchants = json(get("/admin/merchants", admin).expectStatus().isOk());
        assertThat(field(merchants, "Khmer Runners Club", "status")).isEqualTo("active");
        assertThat(field(merchants, "Khmer Runners Club", "owner.name")).isEqualTo("Vannak Sok");
        assertThat(field(merchants, "Siem Reap Arts Collective", "status")).isEqualTo("pending");
        assertThat(field(merchants, "Laugh PP", "status")).isEqualTo("suspended");
        assertThat(JsonPath.<List<Number>>read(merchants,
                "$[?(@.name == 'Khmer Runners Club')].onlineSalesCents").getFirst().longValue()).isPositive();

        String events = json(get("/admin/events", admin).expectStatus().isOk());
        assertThat(field(events, "Phnom Penh Half Marathon 2026", "status")).isEqualTo("live");
        assertThat(field(events, "Kampot River Run 2026", "status")).isEqualTo("onSale");
        assertThat(field(events, "Riverside Night Run 2026", "status")).isEqualTo("ended");
        assertThat(field(events, "Angkor Sunset Music Fest", "status")).isEqualTo("awaitingApproval");
        assertThat(field(events, "Laugh PP: Stand-up Comedy Night", "status")).isEqualTo("paused");
        assertThat(field(events, "Phnom Penh Half Marathon 2026", "capacity")).isEqualTo("220");
        // A place is open every day: its limits are per day, so its capacity is 0 and its sold is every day's.
        assertThat(JsonPath.<List<Map<String, Object>>>read(events, "$[?(@.kind != 'admission')]")).allSatisfy(event ->
                assertThat((Integer) event.get("sold")).as("sold of %s", event.get("name"))
                        .isLessThanOrEqualTo((Integer) event.get("capacity")));
        assertThat(JsonPath.<List<Map<String, Object>>>read(events, "$[?(@.kind == 'admission')]"))
                .extracting(event -> event.get("name"))
                .contains("Garden City Water Park Day Pass", "Phnom Tamao Wildlife Rescue Centre");
        assertThat(field(events, "Phnom Tamao Wildlife Rescue Centre", "status")).isEqualTo("live");
        assertThat(field(events, "Phnom Tamao Wildlife Rescue Centre", "capacity")).isEqualTo("0");
        assertThat(field(events, "Garden City Water Park Day Pass", "status")).isEqualTo("awaitingApproval");

        String bookingId = JsonPath.read(json(get("/merchant/events/" + MARATHON + "/bookings",
                accessTokenFor(OWNER)).expectStatus().isOk()), "$[0].id");
        String found = json(get("/admin/bookings?q=" + bookingId.toLowerCase(), admin).expectStatus().isOk());
        assertThat(JsonPath.<Integer>read(found, "$.total")).isEqualTo(1);
        assertThat(JsonPath.<String>read(found, "$.bookings[0].merchantName")).isEqualTo("Khmer Runners Club");
        assertThat(JsonPath.<String>read(found, "$.bookings[0].eventName")).isEqualTo("Phnom Penh Half Marathon 2026");

        // The test client encodes the space.
        String byBusiness = json(get("/admin/bookings?q=giant ibis", admin).expectStatus().isOk());
        assertThat(JsonPath.<List<String>>read(byBusiness, "$.bookings[*].merchantName"))
                .isNotEmpty().containsOnly("Giant Ibis");
    }

    @Test
    void theListsCountTheChosenPeriod() {
        String admin = adminToken();
        String future = "from=2099-01-01&to=2099-01-31";
        String allTime = "from=2000-01-01&to=" + TODAY.plusYears(5);

        String overview = json(get("/admin/overview?" + future, admin).expectStatus().isOk());
        assertThat(JsonPath.<String>read(overview, "$.period.from")).isEqualTo("2099-01-01");
        assertThat(JsonPath.<String>read(overview, "$.period.to")).isEqualTo("2099-01-31");
        assertThat(JsonPath.<String>read(overview, "$.today")).isEqualTo(TODAY.toString());

        // Nothing was sold, paid or booked in a month to come.
        assertThat(JsonPath.<List<Number>>read(json(get("/admin/merchants?" + future, admin).expectStatus().isOk()),
                "$[*].onlineSalesCents")).allSatisfy(cents -> assertThat(cents.longValue()).isZero());
        assertThat(JsonPath.<List<Object>>read(json(get("/admin/payouts?" + future, admin).expectStatus().isOk()),
                "$.paid")).isEmpty();
        assertThat(JsonPath.<Integer>read(json(get("/admin/bookings?" + future, admin).expectStatus().isOk()),
                "$.total")).isZero();

        // Everything was, some time.
        assertThat(Long.parseLong(field(json(get("/admin/merchants?" + allTime, admin).expectStatus().isOk()),
                "Khmer Runners Club", "onlineSalesCents"))).isPositive();
        assertThat(JsonPath.<List<Object>>read(json(get("/admin/payouts?" + allTime, admin).expectStatus().isOk()),
                "$.paid")).isNotEmpty();
        int everyBooking = JsonPath.read(json(get("/admin/bookings", admin).expectStatus().isOk()), "$.total");
        assertThat(JsonPath.<Integer>read(json(get("/admin/bookings?" + allTime, admin).expectStatus().isOk()),
                "$.total")).isEqualTo(everyBooking);

        get("/admin/overview?from=2026-11-14&to=2026-11-01", admin).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("The start date must be on or before the end date.");
        get("/admin/merchants?from=14-11-2026", admin).expectStatus().isBadRequest()
                .expectBody().jsonPath("$.message").isEqualTo("Write dates like 2026-11-14.");
    }

    @Test
    void bookingsComeAPageAtATime() {
        String admin = adminToken();
        String firstTen = json(get("/admin/bookings?size=10", admin).expectStatus().isOk());
        String pageOne = json(get("/admin/bookings?page=1&size=5", admin).expectStatus().isOk());
        String pageTwo = json(get("/admin/bookings?page=2&size=5", admin).expectStatus().isOk());

        List<String> bothPages = new ArrayList<>(JsonPath.<List<String>>read(pageOne, "$.bookings[*].id"));
        bothPages.addAll(JsonPath.read(pageTwo, "$.bookings[*].id"));
        assertThat(bothPages).hasSize(10).doesNotHaveDuplicates()
                .containsExactlyElementsOf(JsonPath.read(firstTen, "$.bookings[*].id"));
        int total = JsonPath.read(pageTwo, "$.total");
        assertThat(total).isGreaterThan(200);
        assertThat(JsonPath.<Integer>read(pageTwo, "$.page")).isEqualTo(2);
        assertThat(JsonPath.<Integer>read(pageTwo, "$.size")).isEqualTo(5);
        assertThat(JsonPath.<Integer>read(pageTwo, "$.pages")).isEqualTo((total + 4) / 5);

        String byDefault = json(get("/admin/bookings", admin).expectStatus().isOk());
        assertThat(JsonPath.<List<Object>>read(byDefault, "$.bookings")).hasSize(25);
        assertThat(JsonPath.<Integer>read(byDefault, "$.page")).isEqualTo(1);
        String tooBig = json(get("/admin/bookings?size=1000", admin).expectStatus().isOk());
        assertThat(JsonPath.<List<Object>>read(tooBig, "$.bookings")).hasSize(100);
        String pastTheEnd = json(get("/admin/bookings?page=100000&size=5", admin).expectStatus().isOk());
        assertThat(JsonPath.<List<Object>>read(pastTheEnd, "$.bookings")).isEmpty();
        assertThat(JsonPath.<Integer>read(pastTheEnd, "$.total")).isEqualTo(total);
    }

    @Test
    void aNewBusinessSellsOnlyOnceItAndItsEventAreApproved() {
        String owner = registerBusiness("+85570000701", "Approval Test Club");
        get("/me", owner).expectStatus().isOk().expectBody().jsonPath("$.business.status").isEqualTo("pending");

        String event = read(post("/merchant/events", event("Approval Run", TODAY.plusDays(1)), owner)
                .expectStatus().isCreated()
                .expectBody().jsonPath("$.approved").isEqualTo(false), "$.id");

        post("/admin/events/" + event + "/approve", Map.of(), adminToken()).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Approve the business first. Its events can go on sale once it is active.");
        post(doorSales(event), doorSale(), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Pin is still reviewing your business. You can sell tickets once it is approved.");

        approveBusinessOf(owner);
        get("/me", owner).expectStatus().isOk().expectBody().jsonPath("$.business.status").isEqualTo("active");
        post(doorSales(event), doorSale(), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Pin is still reviewing this event. You can sell tickets once it is approved.");

        approveEvent(event);
        post("/admin/events/" + event + "/approve", Map.of(), adminToken()).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Approval Run is already approved.");
        get("/merchant/events/" + event, owner).expectStatus().isOk()
                .expectBody().jsonPath("$.approved").isEqualTo(true);
        post(doorSales(event), doorSale(), owner).expectStatus().isCreated();
        assertThat(field(json(get("/admin/events", adminToken()).expectStatus().isOk()), "Approval Run", "status"))
                .isEqualTo("onSale");
    }

    @Test
    void aSuspendedBusinessCannotSellOrPublishButStillAdmitsTicketsItSold() {
        String owner = registerBusiness("+85570000702", "Suspension Test Club");
        approveBusinessOf(owner);
        String businessId = read(get("/me", owner).expectStatus().isOk().expectBody(), "$.business.id");
        String event = read(post("/merchant/events", event("Suspension Run", TODAY), owner)
                .expectStatus().isCreated().expectBody(), "$.id");
        approveEvent(event);
        String booking = read(post(doorSales(event), doorSale(), owner).expectStatus().isCreated().expectBody(),
                "$.id");

        post("/admin/merchants/" + businessId + "/suspend", Map.of(), adminToken()).expectStatus().isOk()
                .expectBody().jsonPath("$.status").isEqualTo("suspended");
        get("/me", owner).expectStatus().isOk().expectBody().jsonPath("$.business.status").isEqualTo("suspended");
        post(doorSales(event), doorSale(), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Pin has suspended your business. Contact Pin to sell tickets again.");
        post("/merchant/events", event("Another Run", TODAY.plusDays(2)), owner).expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message")
                .isEqualTo("Pin has suspended your business. Contact Pin to publish events again.");
        assertThat(field(json(get("/admin/events", adminToken()).expectStatus().isOk()), "Suspension Run", "status"))
                .isEqualTo("paused");
        post("/merchant/checkins", Map.of("eventId", event, "code", booking), owner).expectStatus().isOk()
                .expectBody().jsonPath("$.result").isEqualTo("admitted");

        post("/admin/merchants/" + businessId + "/suspend", Map.of(), adminToken()).expectStatus().isEqualTo(409);
        post("/admin/merchants/" + businessId + "/reinstate", Map.of(), adminToken()).expectStatus().isOk()
                .expectBody().jsonPath("$.status").isEqualTo("active");
        post(doorSales(event), doorSale(), owner).expectStatus().isCreated();
    }

    @Test
    void payingABusinessCoversItsOnlineSalesExactlyOnce() {
        String admin = adminToken();
        String payouts = json(get("/admin/payouts", admin).expectStatus().isOk());
        String owed = "$.owed[?(@.merchantId == '" + LEGEND_CINEMA + "')]";
        long gross = JsonPath.<List<Number>>read(payouts, owed + ".grossCents").getFirst().longValue();
        long commission = JsonPath.<List<Number>>read(payouts, owed + ".commissionCents").getFirst().longValue();
        long net = JsonPath.<List<Number>>read(payouts, owed + ".netCents").getFirst().longValue();
        assertThat(net).isEqualTo(gross - commission);
        // 5% of online sales, rounded per booking.
        assertThat(commission).isBetween(gross / 20 - 100, gross / 20 + 100);

        post("/admin/payouts", Map.of("merchantId", LEGEND_CINEMA, "netCents", net + 1), admin)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("The amount owed is now "
                        + Money.ofCents(net).toDisplayString() + ". Check it and mark it as paid again.");
        post("/admin/payouts", Map.of("merchantId", LEGEND_CINEMA, "netCents", net), admin)
                .expectStatus().isCreated()
                .expectBody()
                .jsonPath("$.netCents").isEqualTo(net)
                .jsonPath("$.merchantName").isEqualTo("Legend Cinema")
                .jsonPath("$.paidBy").isEqualTo("Moniroth Prak");
        post("/admin/payouts", Map.of("merchantId", LEGEND_CINEMA, "netCents", net), admin)
                .expectStatus().isEqualTo(409)
                .expectBody().jsonPath("$.message").isEqualTo("Nothing is owed to this business right now.");

        String merchantView = json(get("/merchant/payouts", accessTokenFor(LEGEND_CINEMA_OWNER)).expectStatus().isOk());
        assertThat(JsonPath.<Number>read(merchantView, "$.due.netCents").longValue()).isZero();
        assertThat(JsonPath.<Number>read(merchantView, "$.paid[0].netCents").longValue()).isEqualTo(net);
    }

    @Test
    void theMerchantAppShowsWhatPinOwesAndHasPaidToTheOwnerOnly() {
        String view = json(get("/merchant/payouts", accessTokenFor(OWNER)).expectStatus().isOk());
        // The demo's run three weeks ago is paid out; today's and next week's sales are owed.
        assertThat(JsonPath.<List<Object>>read(view, "$.paid")).isNotEmpty();
        assertThat(JsonPath.<Number>read(view, "$.due.netCents").longValue()).isPositive();
        get("/merchant/payouts", accessTokenFor(SECOND_SCANNER)).expectStatus().isForbidden();
    }

    @Test
    void unknownBusinessesAndEventsAreNotFound() {
        post("/admin/merchants/not-an-id/approve", Map.of(), adminToken()).expectStatus().isNotFound();
        post("/admin/merchants/" + UUID.randomUUID() + "/approve", Map.of(), adminToken()).expectStatus().isNotFound();
        post("/admin/events/" + UUID.randomUUID() + "/approve", Map.of(), adminToken()).expectStatus().isNotFound();
        post("/admin/payouts", Map.of("merchantId", UUID.randomUUID().toString(), "netCents", 0), adminToken())
                .expectStatus().isNotFound();
    }

    // ------------------------------------------------------------------ helpers

    /** A new admin with this password, set with the development reset. */
    private void addAdmin(String email, String password) {
        jdbc.sql("insert into admins (id, email, name) values (:id, :email, 'Test Admin')")
                .param("id", Ids.newId())
                .param("email", email)
                .update();
        post("/admin/auth/password-reset", Map.of("email", email, "newPassword", password))
                .expectStatus().isNoContent();
    }

    /** Signs a newly added admin in with their temporary password, chooses {@link #OWN_PASSWORD}; their token. */
    private String firstSignIn(String email, String temporaryPassword) {
        String token = read(adminSignIn(email, temporaryPassword).expectStatus().isOk().expectBody(), "$.accessToken");
        changePassword(token, temporaryPassword, OWN_PASSWORD).expectStatus().isNoContent();
        return token;
    }

    private ResponseSpec changePassword(String accessToken, String currentPassword, String newPassword) {
        return post("/admin/me/password", Map.of("currentPassword", currentPassword, "newPassword", newPassword),
                accessToken);
    }

    private static void expectWrongEmailOrPassword(ResponseSpec response) {
        response.expectStatus().isBadRequest()
                .expectBody()
                .jsonPath("$.code").isEqualTo("rejected")
                .jsonPath("$.message").isEqualTo("The email or password is wrong.");
    }

    /** A field of the list entry with this name, as text. */
    private static String field(String json, String name, String path) {
        List<Object> values = JsonPath.read(json, "$[?(@.name == '" + name + "')]." + path);
        assertThat(values).as(name).hasSize(1);
        return String.valueOf(values.getFirst());
    }

    private static Map<String, Object> event(String name, LocalDate day) {
        return Map.of("name", name, "startsAt", day + "T23:00:00", "venue", "Riverside", "kind", "marathon",
                "ticketTypes", List.of(Map.of("name", "5K", "priceCents", 1000, "quantity", 50)));
    }

    private static String doorSales(String eventId) {
        return "/merchant/events/" + eventId + "/door-sales";
    }

    private static Map<String, Object> doorSale() {
        return Map.of("lines", List.of(Map.of("ticketType", "5K", "quantity", 1)), "buyerPhone", "+85512000700",
                "payment", "cash");
    }

    private static String json(ResponseSpec response) {
        return new String(response.expectBody().returnResult().getResponseBody());
    }
}
