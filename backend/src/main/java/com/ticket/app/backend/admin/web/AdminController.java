package com.ticket.app.backend.admin.web;

import java.io.IOException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.admin.application.BackOfficeService;
import com.ticket.app.backend.admin.domain.Admin;
import com.ticket.app.backend.admin.web.AdminDtos.ApprovedEventResponse;
import com.ticket.app.backend.admin.web.AdminDtos.BookingsResponse;
import com.ticket.app.backend.admin.web.AdminDtos.EventResponse;
import com.ticket.app.backend.admin.web.AdminDtos.ImageResponse;
import com.ticket.app.backend.admin.web.AdminDtos.MerchantResponse;
import com.ticket.app.backend.admin.web.AdminDtos.MerchantStatusResponse;
import com.ticket.app.backend.admin.web.AdminDtos.OverviewResponse;
import com.ticket.app.backend.admin.web.AdminDtos.PaidResponse;
import com.ticket.app.backend.admin.web.AdminDtos.PayRequest;
import com.ticket.app.backend.admin.web.AdminDtos.PayoutsResponse;
import com.ticket.app.backend.admin.web.AdminDtos.PeriodResponse;
import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.event.application.EventImageService;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.shared.domain.Money;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The admin panel's data and actions. Every path under {@code /admin} needs an admin
 * session ({@code SecurityConfig}); merchants' tokens are refused.
 */
@RestController
@RequestMapping("/admin")
class AdminController {

    private final BackOfficeService backOffice;
    private final EventImageService eventImages;
    private final ZoneId zone;

    AdminController(BackOfficeService backOffice, EventImageService eventImages, Clock clock) {
        this.backOffice = backOffice;
        this.eventImages = eventImages;
        this.zone = clock.getZone();
    }

    /**
     * The period figures are counted for, Pin's today, and the commission rate for new
     * events. {@code from} and {@code to} (e.g. {@code 2026-11-01}, both included) choose
     * the period on this and the other lists; either left out means the 1st of this month
     * or today. 400 when {@code from} is after {@code to}.
     */
    @GetMapping("/overview")
    OverviewResponse overview(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return new OverviewResponse(PeriodResponse.of(backOffice.period(from, to)), backOffice.today(),
                backOffice.commissionRate().doubleValue());
    }

    /** Every business, with its online sales and commission in the period. */
    @GetMapping("/merchants")
    List<MerchantResponse> merchants(@RequestParam(required = false) String from,
                                     @RequestParam(required = false) String to) {
        return backOffice.merchants(backOffice.period(from, to)).stream()
                .map(merchant -> MerchantResponse.of(merchant, zone))
                .toList();
    }

    @PostMapping("/merchants/{merchantId}/approve")
    MerchantStatusResponse approveMerchant(@PathVariable String merchantId) {
        return MerchantStatusResponse.of(backOffice.approveMerchant(BusinessId.parse(merchantId)));
    }

    @PostMapping("/merchants/{merchantId}/suspend")
    MerchantStatusResponse suspendMerchant(@PathVariable String merchantId) {
        return MerchantStatusResponse.of(backOffice.suspendMerchant(BusinessId.parse(merchantId)));
    }

    @PostMapping("/merchants/{merchantId}/reinstate")
    MerchantStatusResponse reinstateMerchant(@PathVariable String merchantId) {
        return MerchantStatusResponse.of(backOffice.reinstateMerchant(BusinessId.parse(merchantId)));
    }

    @GetMapping("/events")
    List<EventResponse> events() {
        LocalDate today = backOffice.today();
        return backOffice.events().stream().map(event -> EventResponse.of(event, today)).toList();
    }

    @PostMapping("/events/{eventId}/approve")
    ApprovedEventResponse approveEvent(@PathVariable String eventId) {
        return ApprovedEventResponse.of(backOffice.approveEvent(EventId.parse(eventId)));
    }

    /**
     * Sets or replaces any event's cover image, for example one a business sent in or one that should
     * be changed. The picture is the request body as it is: a JPEG or PNG up to 5 MB.
     */
    @PutMapping("/events/{eventId}/image")
    ImageResponse putImage(@PathVariable String eventId, HttpServletRequest request) throws IOException {
        byte[] picture = request.getInputStream().readNBytes(EventImageService.MAX_UPLOAD_BYTES + 1);
        return ImageResponse.of(eventImages.setByAdmin(EventId.parse(eventId), picture));
    }

    /** Takes down an event's cover image, for example one that should not be shown. */
    @DeleteMapping("/events/{eventId}/image")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void removeImage(@PathVariable String eventId) {
        eventImages.removeByAdmin(EventId.parse(eventId));
    }

    /**
     * The bookings of every business, newest first, a page at a time.
     *
     * @param q    part of a booking ID, buyer, event or business name, or 3+ phone digits
     * @param from with {@code to}: only bookings made in the period; both left out: any time
     * @param page from 1
     * @param size bookings per page, at most 100
     */
    @GetMapping("/bookings")
    BookingsResponse bookings(@RequestParam(defaultValue = "") String q,
                              @RequestParam(required = false) String from,
                              @RequestParam(required = false) String to,
                              @RequestParam(defaultValue = "1") int page,
                              @RequestParam(defaultValue = "25") int size) {
        Optional<BackOfficeService.Period> period = from == null && to == null
                ? Optional.empty()
                : Optional.of(backOffice.period(from, to));
        return BookingsResponse.of(backOffice.bookings(q, period, page, size), zone);
    }

    /** What Pin owes each business now, and the payouts made in the period. */
    @GetMapping("/payouts")
    PayoutsResponse payouts(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return PayoutsResponse.of(backOffice.payouts(backOffice.period(from, to)), zone);
    }

    /** Records that the admin sent the business everything it is owed. */
    @PostMapping("/payouts")
    @ResponseStatus(HttpStatus.CREATED)
    PaidResponse pay(@AuthenticationPrincipal Admin me, @Valid @RequestBody PayRequest request) {
        return PaidResponse.of(backOffice.pay(me, BusinessId.parse(request.merchantId()),
                Money.ofCents(request.netCents())), zone);
    }
}
