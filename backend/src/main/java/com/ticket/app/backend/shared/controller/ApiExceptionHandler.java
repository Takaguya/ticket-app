package com.ticket.app.backend.shared.controller;

import com.ticket.app.backend.shared.model.DomainException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.TransientDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.transaction.CannotCreateTransactionException;
import org.springframework.transaction.TransactionSystemException;
import org.springframework.validation.FieldError;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import com.ticket.app.backend.shared.dto.ApiError;

/** Answers every failed request as an {@link ApiError}. */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(DomainException.class)
    ResponseEntity<ApiError> domain(DomainException e) {
        HttpStatus status = switch (e.kind()) {
            case INVALID -> HttpStatus.BAD_REQUEST;
            case CONFLICT -> HttpStatus.CONFLICT;
            case NOT_FOUND -> HttpStatus.NOT_FOUND;
            case TOO_SOON -> HttpStatus.TOO_MANY_REQUESTS;
        };
        return answer(status, e.code(), e.getMessage());
    }

    /** A request field failed its {@code @Valid} check: its message is shown to the person. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> invalid(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .findFirst()
                .orElse("Please check the details and try again.");
        return answer(HttpStatus.BAD_REQUEST, ApiError.REJECTED, message);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> unreadable(HttpMessageNotReadableException e) {
        return answer(HttpStatus.BAD_REQUEST, ApiError.BAD_REQUEST, "The request could not be read.");
    }

    /**
     * The database is down or the connection to it broke, possibly while committing.
     * 503, so the app knows the outcome is unknown and retries with the same attempt ID.
     */
    @ExceptionHandler({DataAccessResourceFailureException.class, TransientDataAccessException.class,
            CannotCreateTransactionException.class, TransactionSystemException.class})
    ResponseEntity<ApiError> databaseUnavailable(Exception e) {
        log.warn("Database unavailable: {}", e.getMessage());
        return answer(HttpStatus.SERVICE_UNAVAILABLE, ApiError.UNAVAILABLE, ApiError.UNAVAILABLE_MESSAGE);
    }

    /** Thrown by {@code @PreAuthorize} role checks. */
    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ApiError> denied(AccessDeniedException e) {
        return answer(HttpStatus.FORBIDDEN, ApiError.FORBIDDEN, "Only the business owner can do this.");
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> other(Exception e) {
        // Spring's own request errors (unknown path, wrong method, ...) carry their status.
        if (e instanceof ErrorResponse response) {
            HttpStatusCode status = response.getStatusCode();
            String code = status.value() == 404 ? ApiError.NOT_FOUND : ApiError.BAD_REQUEST;
            return answer(status, code, response.getBody().getTitle());
        }
        log.error("Request failed", e);
        return answer(HttpStatus.INTERNAL_SERVER_ERROR, ApiError.SERVER_ERROR,
                "Something went wrong. Please try again.");
    }

    private static ResponseEntity<ApiError> answer(HttpStatusCode status, String code, String message) {
        return ResponseEntity.status(status).body(new ApiError(code, message));
    }
}
