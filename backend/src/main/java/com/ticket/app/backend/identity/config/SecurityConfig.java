package com.ticket.app.backend.identity.config;

import java.io.IOException;
import java.time.Clock;
import java.util.Set;

import com.ticket.app.backend.identity.service.AdminSessionService;
import com.ticket.app.backend.identity.service.BuyerSessionService;
import com.ticket.app.backend.identity.service.SessionService;
import com.ticket.app.backend.shared.config.PinProperties;
import com.ticket.app.backend.shared.dto.ApiError;
import com.ticket.app.backend.shared.service.RequestRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Every endpoint needs a signed-in member except the ones used to sign in or create
 * an account. Owner-only endpoints say so with {@code @PreAuthorize("hasRole('OWNER')")}.
 * Paths under {@code /admin} are for Pin's admins only, and admins can use nothing
 * else. Paths under {@code /buyer} and {@code /catalog} are for the user app's buyers
 * only, and buyers can use nothing else (but sign out): the three kinds of session never
 * open each other's endpoints.
 */
@Configuration(proxyBeanMethods = false)
@EnableMethodSecurity
public class SecurityConfig {

    /** The error code for an admin who must choose their own password first; the panel acts on it. */
    static final String PASSWORD_CHANGE_REQUIRED = "password_change_required";

    /** Adding and removing admins, and changing their role: super admins only. */
    private static final String[] ADMIN_TEAM_CHANGES = {
            "/admin/admins", "/admin/admins/*/remove", "/admin/admins/*/role",
    };

    private static final String[] PUBLIC_POSTS = {
            "/auth/otp", "/auth/verify", "/merchant/businesses", "/merchant/staff/join", "/admin/auth/sign-in",
            "/admin/auth/password-reset", "/buyer/register",
    };

    /** What a buyer may use: the user app's own endpoints. */
    private static final String[] BUYER_PATHS = {"/buyer/**", "/catalog/**"};

    @Bean
    SecurityFilterChain api(HttpSecurity http, SessionService sessions, BuyerSessionService buyerSessions,
                            AdminSessionService adminSessions, PinProperties properties, Clock clock)
            throws Exception {
        var signInLimit = new SignInRateLimitFilter(Set.of(PUBLIC_POSTS),
                new RequestRateLimiter(properties.signInRequestsPerMinute(), clock));
        http
                // Apps send a bearer token, never cookies, so there is no CSRF to defend against.
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .logout(logout -> logout.disable())
                .requestCache(cache -> cache.disable())
                .authorizeHttpRequests(paths -> paths
                        .requestMatchers(HttpMethod.POST, PUBLIC_POSTS).permitAll()
                        // Whether the sign-in page may offer "forgot password".
                        .requestMatchers(HttpMethod.GET, "/admin/auth/password-reset").permitAll()
                        .requestMatchers("/error").permitAll()
                        // Event cover images: shown by the apps without signing in, and found only by an event's ID.
                        .requestMatchers(HttpMethod.GET, "/images/events/*").permitAll()
                        // All an admin with a temporary password can do: choose their own, or leave.
                        .requestMatchers(HttpMethod.GET, "/admin/me").hasAnyRole("ADMIN", "NEW_ADMIN")
                        .requestMatchers(HttpMethod.POST, "/admin/me/password", "/admin/auth/sign-out")
                                .hasAnyRole("ADMIN", "NEW_ADMIN")
                        .requestMatchers(HttpMethod.POST, ADMIN_TEAM_CHANGES).hasRole("SUPER_ADMIN")
                        .requestMatchers("/admin/**").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.POST, "/auth/sign-out").hasAnyRole("OWNER", "SCANNER", "BUYER")
                        .requestMatchers(BUYER_PATHS).hasRole("BUYER")
                        .anyRequest().hasAnyRole("OWNER", "SCANNER"))
                .addFilterBefore(signInLimit, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(new SessionAuthenticationFilter(sessions, buyerSessions, adminSessions),
                        UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(errors -> errors
                        .authenticationEntryPoint((request, response, e) ->
                                writeError(response, 401, ApiError.UNAUTHORIZED, "Please sign in again."))
                        .accessDeniedHandler((request, response, e) -> {
                            if (isAdminPath(request) && isNewAdmin()) {
                                writeError(response, 403, PASSWORD_CHANGE_REQUIRED, "Choose your own password first.");
                            } else if (isAdminTeamPath(request) && hasRole("ROLE_ADMIN")) {
                                writeError(response, 403, ApiError.FORBIDDEN, "Only super admins can manage admins.");
                            } else if (isBuyerPath(request)) {
                                writeError(response, 403, ApiError.FORBIDDEN, "Sign in with the Pin app to do this.");
                            } else {
                                writeError(response, 403, ApiError.FORBIDDEN, isAdminPath(request)
                                        ? "Only Pin admins can do this."
                                        : "Sign in with Pin Merchant to do this.");
                            }
                        }));
        return http.build();
    }

    /** This request is signed in with a temporary password (see {@link SessionAuthenticationFilter#NEW_ADMIN_ROLE}). */
    public static boolean isNewAdmin() {
        return hasRole(SessionAuthenticationFilter.NEW_ADMIN_ROLE);
    }

    private static boolean hasRole(String role) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        return authentication != null && authentication.getAuthorities().stream()
                .anyMatch(authority -> role.equals(authority.getAuthority()));
    }

    private static boolean isAdminTeamPath(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return path.equals("/admin/admins") || path.startsWith("/admin/admins/");
    }

    private static boolean isBuyerPath(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return path.equals("/buyer") || path.startsWith("/buyer/") || path.equals("/catalog")
                || path.startsWith("/catalog/");
    }

    private static boolean isAdminPath(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return path.equals("/admin") || path.startsWith("/admin/");
    }

    static void writeError(HttpServletResponse response, int status, String code, String message)
            throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        // Fixed messages without quotes or backslashes, so they need no escaping.
        response.getWriter().write("{\"code\":\"" + code + "\",\"message\":\"" + message + "\"}");
    }
}
