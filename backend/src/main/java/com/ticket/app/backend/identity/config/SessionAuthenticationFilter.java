package com.ticket.app.backend.identity.config;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.admin.model.Admin;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.identity.service.AdminSessionService;
import com.ticket.app.backend.identity.service.BuyerSessionService;
import com.ticket.app.backend.identity.service.SessionService;
import com.ticket.app.backend.shared.dto.ApiError;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.TransactionException;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Signs the request in when it carries {@code Authorization: Bearer <token>} for a
 * live session. For the merchant app the principal is the {@link StaffMember} and the
 * authority {@code ROLE_OWNER} or {@code ROLE_SCANNER}; for the user app the principal
 * is the {@link Buyer} and the authority {@code ROLE_BUYER}; for the admin panel the
 * principal is the {@link Admin} and the authority {@code ROLE_ADMIN}, or
 * {@link #NEW_ADMIN_ROLE} while the admin still has a temporary password.
 *
 * <p>Made by {@link SecurityConfig}, not a bean, so it runs only inside the
 * security filter chain.
 */
public class SessionAuthenticationFilter extends OncePerRequestFilter {

    /** An admin who has not chosen their own password yet: may only do that, or sign out. */
    static final String NEW_ADMIN_ROLE = "ROLE_NEW_ADMIN";

    /** A buyer signed in to the user app. */
    static final String BUYER_ROLE = "ROLE_BUYER";

    private final SessionService sessions;
    private final BuyerSessionService buyerSessions;
    private final AdminSessionService adminSessions;

    SessionAuthenticationFilter(SessionService sessions, BuyerSessionService buyerSessions,
                                AdminSessionService adminSessions) {
        this.sessions = sessions;
        this.buyerSessions = buyerSessions;
        this.adminSessions = adminSessions;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        try {
            Optional<String> token = bearerToken(request.getHeader(HttpHeaders.AUTHORIZATION));
            Optional<StaffMember> member = token.flatMap(sessions::resolve);
            if (member.isPresent()) {
                signIn(member.get(), List.of("ROLE_" + member.get().role().name()));
            } else {
                Optional<Buyer> buyer = token.flatMap(buyerSessions::resolve);
                if (buyer.isPresent()) {
                    signIn(buyer.get(), List.of(BUYER_ROLE));
                } else {
                    token.flatMap(adminSessions::resolve).ifPresent(signedIn -> signIn(signedIn.admin(),
                            adminRoles(signedIn.admin(), signedIn.mustChangePassword())));
                }
            }
        } catch (DataAccessException | TransactionException e) {
            // The session cannot be checked while the database is down: say so, rather
            // than "sign in again", so the app keeps its session and retries.
            SecurityConfig.writeError(response, 503, ApiError.UNAVAILABLE, ApiError.UNAVAILABLE_MESSAGE);
            return;
        }
        chain.doFilter(request, response);
    }

    /** The token in an {@code Authorization} header value, if it is a bearer token. */
    public static Optional<String> bearerToken(String header) {
        if (header == null || !header.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return Optional.empty();
        }
        String token = header.substring(7).strip();
        return token.isEmpty() ? Optional.empty() : Optional.of(token);
    }

    /**
     * {@code ROLE_ADMIN}, and {@code ROLE_SUPER_ADMIN} too for super admins; only
     * {@link #NEW_ADMIN_ROLE} while the admin still has a temporary password.
     */
    private static List<String> adminRoles(Admin admin, boolean mustChangePassword) {
        if (mustChangePassword) {
            return List.of(NEW_ADMIN_ROLE);
        }
        return admin.managesAdmins() ? List.of("ROLE_ADMIN", "ROLE_SUPER_ADMIN") : List.of("ROLE_ADMIN");
    }

    private static void signIn(Object principal, List<String> roles) {
        var authorities = roles.stream().map(SimpleGrantedAuthority::new).toList();
        var authentication = UsernamePasswordAuthenticationToken.authenticated(principal, null, authorities);
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
    }
}
