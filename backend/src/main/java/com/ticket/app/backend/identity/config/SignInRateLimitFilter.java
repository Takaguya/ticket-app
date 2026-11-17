package com.ticket.app.backend.identity.config;

import java.io.IOException;
import java.util.Set;

import com.ticket.app.backend.shared.dto.ApiError;
import com.ticket.app.backend.shared.service.RequestRateLimiter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Limits how often one client address may call the sign-in and sign-up endpoints,
 * so codes and join codes cannot be guessed quickly and SMS cannot be sent in bulk.
 * Other endpoints need a session and are not limited here.
 *
 * <p>Behind a proxy, set {@code server.forward-headers-strategy} so the client's own
 * address is used rather than the proxy's.
 */
class SignInRateLimitFilter extends OncePerRequestFilter {

    private final Set<String> paths;
    private final RequestRateLimiter limiter;

    SignInRateLimitFilter(Set<String> paths, RequestRateLimiter limiter) {
        this.paths = paths;
        this.limiter = limiter;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !paths.contains(request.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        if (!limiter.tryAcquire(request.getRemoteAddr())) {
            SecurityConfig.writeError(response, 429, ApiError.REJECTED,
                    "Too many attempts. Please wait a minute and try again.");
            return;
        }
        chain.doFilter(request, response);
    }
}
