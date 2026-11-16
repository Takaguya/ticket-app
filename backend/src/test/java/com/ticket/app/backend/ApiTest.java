package com.ticket.app.backend;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.jayway.jsonpath.JsonPath;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.test.web.servlet.client.RestTestClient.BodyContentSpec;
import org.springframework.test.web.servlet.client.RestTestClient.ResponseSpec;

/**
 * Base of the tests that call the HTTP API of a running server with a real
 * database and the demo data. All of them share one server and database (Spring
 * reuses the context), so they must not depend on running in any order.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        // The test profile and a local database are what allow the development switches below to be on
        // (see DevSwitchesGuard).
        properties = {"spring.profiles.active=test", "pin.otp.dev-code=123456", "pin.demo-data=true",
                // All tests call from one address, far more often than a person would.
                "pin.sign-in-requests-per-minute=100000",
                "pin.admin-account.email=" + ApiTest.SETUP_ADMIN_EMAIL,
                "pin.admin-account.password=" + ApiTest.SETUP_ADMIN_PASSWORD,
                "pin.admin-account.name=Setup Admin",
                "pin.admin-sign-in.dev-password-reset=true"})
@AutoConfigureRestTestClient
@Import(TestcontainersConfiguration.class)
public abstract class ApiTest {

    protected static final String CODE = "123456";

    /**
     * An admin added on startup from {@code pin.admin-account}. Only the admin sign-in
     * tests use it, and they lock it.
     */
    protected static final String SETUP_ADMIN_EMAIL = "setup.admin@pin.example";
    protected static final String SETUP_ADMIN_PASSWORD = "setup-admin-password";

    /** Vannak Sok, owner of the demo business. */
    protected static final String OWNER = "+85512345678";

    /** Dara Keo, scanner. Only the sign-in tests use this number, and they sign it out. */
    protected static final String SCANNER = "+85598765432";

    /** Sreyneang Lim, scanner. */
    protected static final String SECOND_SCANNER = "+85587654321";

    /** Moniroth Prak, the demo admin. */
    protected static final String ADMIN_EMAIL = "moniroth@pin.example";
    protected static final String ADMIN_PASSWORD = "pin-demo-admin";

    /**
     * Access tokens per server and number. A number can only ask for a code every 30
     * seconds. Tests with their own Spring context have their own server and database,
     * where another server's tokens mean nothing.
     */
    private static final Map<String, String> ACCESS_TOKENS = new ConcurrentHashMap<>();

    @Autowired
    protected RestTestClient http;

    @Value("${local.server.port}")
    private int port;

    /** Signs the number in once for all tests and returns its access token. */
    protected String accessTokenFor(String phone) {
        return ACCESS_TOKENS.computeIfAbsent(port + " " + phone, key -> {
            sendCode(phone);
            return read(verify(phone, CODE).expectStatus().isOk().expectBody(), "$.session.accessToken");
        });
    }

    /** Registers a new business for a number that has no account, and returns the owner's access token. */
    protected String registerBusiness(String phone, String businessName) {
        return registerBusiness(phone, businessName, "events");
    }

    /** Like {@link #registerBusiness(String, String)} for a business of this type: events, bus, cinema or admission. */
    protected String registerBusiness(String phone, String businessName, String type) {
        sendCode(phone);
        String registrationToken = read(verify(phone, CODE).expectStatus().isOk().expectBody(),
                "$.registrationToken");
        return read(post("/merchant/businesses", Map.of(
                "registrationToken", registrationToken,
                "businessName", businessName,
                "contactName", "Test Owner",
                "type", type)).expectStatus().isCreated().expectBody(), "$.accessToken");
    }

    /** Signs a buyer up for a number that has no account yet, and returns their access token. */
    protected String registerBuyer(String phone, String name, String gender) {
        sendCode(phone);
        String registrationToken = read(post("/auth/verify", Map.of("phone", phone, "code", CODE,
                "purpose", "register", "app", "user")).expectStatus().isOk().expectBody(), "$.registrationToken");
        return read(post("/buyer/register", Map.of(
                "registrationToken", registrationToken,
                "name", name,
                "gender", gender,
                "dateOfBirth", "1995-06-15")).expectStatus().isCreated().expectBody(), "$.accessToken");
    }

    /** The demo admin's access token, signed in once for all tests. */
    protected String adminToken() {
        return ACCESS_TOKENS.computeIfAbsent(port + " admin " + ADMIN_EMAIL, key ->
                read(adminSignIn(ADMIN_EMAIL, ADMIN_PASSWORD).expectStatus().isOk().expectBody(), "$.accessToken"));
    }

    protected ResponseSpec adminSignIn(String email, String password) {
        return post("/admin/auth/sign-in", Map.of("email", email, "password", password));
    }

    /** The admin puts a newly published event on sale. */
    protected void approveEvent(String eventId) {
        post("/admin/events/" + eventId + "/approve", Map.of(), adminToken()).expectStatus().isOk();
    }

    /** The admin approves the business of a newly registered owner, so it can sell. */
    protected void approveBusinessOf(String ownerToken) {
        String businessId = read(get("/me", ownerToken).expectStatus().isOk().expectBody(), "$.business.id");
        post("/admin/merchants/" + businessId + "/approve", Map.of(), adminToken()).expectStatus().isOk();
    }

    protected void sendCode(String phone) {
        post("/auth/otp", Map.of("phone", phone, "purpose", "login")).expectStatus().isNoContent();
    }

    protected ResponseSpec verify(String phone, String code) {
        return post("/auth/verify", Map.of("phone", phone, "code", code, "purpose", "login", "app", "merchant"));
    }

    protected ResponseSpec get(String path, String accessToken) {
        return http.get().uri(path).header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken).exchange();
    }

    protected ResponseSpec post(String path, Object body) {
        return http.post().uri(path).contentType(MediaType.APPLICATION_JSON).body(body).exchange();
    }

    protected ResponseSpec post(String path, Object body, String accessToken) {
        return http.post().uri(path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .exchange();
    }

    /** A value from the JSON body. */
    protected static <T> T read(BodyContentSpec body, String jsonPath) {
        byte[] bytes = body.returnResult().getResponseBody();
        return JsonPath.read(new String(bytes, StandardCharsets.UTF_8), jsonPath);
    }
}
