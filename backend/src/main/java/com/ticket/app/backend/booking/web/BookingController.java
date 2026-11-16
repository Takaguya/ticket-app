package com.ticket.app.backend.booking.web;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.ZoneId;
import java.util.List;

import com.ticket.app.backend.booking.application.BookingQueryService;
import com.ticket.app.backend.booking.application.BookingQueryService.EventBookings;
import com.ticket.app.backend.booking.application.CancellationService;
import com.ticket.app.backend.booking.application.DoorSaleService;
import com.ticket.app.backend.booking.domain.BookingId;
import com.ticket.app.backend.booking.domain.BookingSearch;
import com.ticket.app.backend.booking.domain.BookingStatus;
import com.ticket.app.backend.booking.web.BookingDtos.BookingResponse;
import com.ticket.app.backend.booking.web.BookingDtos.CancelRequest;
import com.ticket.app.backend.booking.web.BookingDtos.DoorSaleRequest;
import com.ticket.app.backend.booking.web.BookingDtos.SummaryResponse;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.shared.domain.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Bookings and sales. Scanners can list bookings; the summary, the CSV export, door
 * sales and cancelling are for the owner.
 */
@RestController
@RequestMapping("/merchant")
class BookingController {

    private static final MediaType CSV = new MediaType("text", "csv", StandardCharsets.UTF_8);

    private final BookingQueryService queries;
    private final DoorSaleService doorSales;
    private final CancellationService cancellations;
    private final ZoneId zone;

    BookingController(BookingQueryService queries, DoorSaleService doorSales, CancellationService cancellations,
                      Clock clock) {
        this.queries = queries;
        this.doorSales = doorSales;
        this.cancellations = cancellations;
        this.zone = clock.getZone();
    }

    /**
     * Every booking of the business, for all its events. The merchant app keeps this
     * list and works out each screen's numbers from it.
     */
    @GetMapping("/bookings")
    List<BookingResponse> allBookings(@AuthenticationPrincipal StaffMember me) {
        return queries.allOf(me).stream().map(booking -> BookingResponse.of(booking, zone)).toList();
    }

    /**
     * One event's bookings, sorted by buyer name.
     *
     * @param q      part of a name or booking ID, or 3+ digits of a phone number
     * @param status open, checkedIn or cancelled; all when left out
     */
    @GetMapping("/events/{eventId}/bookings")
    List<BookingResponse> bookings(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId,
                                   @RequestParam(defaultValue = "") String q,
                                   @RequestParam(required = false) String status) {
        return queries.search(me, EventId.parse(eventId), search(q, status)).bookings().stream()
                .map(booking -> BookingResponse.of(booking, zone))
                .toList();
    }

    /** The same list as a spreadsheet file. */
    @GetMapping("/events/{eventId}/bookings.csv")
    @PreAuthorize("hasRole('OWNER')")
    ResponseEntity<String> bookingsCsv(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId,
                                       @RequestParam(defaultValue = "") String q,
                                       @RequestParam(required = false) String status) {
        BookingSearch search = search(q, status);
        EventBookings found = queries.search(me, EventId.parse(eventId), search);
        ContentDisposition attachment = ContentDisposition.attachment()
                .filename(BookingsCsv.fileName(found.event(), search.status()))
                .build();
        return ResponseEntity.ok()
                .contentType(CSV)
                .header(HttpHeaders.CONTENT_DISPOSITION, attachment.toString())
                .body(BookingsCsv.content(found.event(), found.bookings(), zone));
    }

    /** Sold, checked in, left, revenue, commission and what the business receives. */
    @GetMapping("/events/{eventId}/summary")
    @PreAuthorize("hasRole('OWNER')")
    SummaryResponse summary(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId) {
        return SummaryResponse.of(queries.summary(me, EventId.parse(eventId)));
    }

    /**
     * Cancels a booking, for a reason the buyer is shown. Pin refunds an online booking
     * in full; a door sale is paid back by the business. Cancelling a cancelled booking
     * answers it as it is. 409 when it is checked in or its event has ended.
     */
    @PostMapping("/bookings/{bookingId}/cancel")
    @PreAuthorize("hasRole('OWNER')")
    BookingResponse cancel(@AuthenticationPrincipal StaffMember me, @PathVariable String bookingId,
                           @Valid @RequestBody CancelRequest request) {
        BookingId id = BookingId.parse(bookingId)
                .orElseThrow(() -> new NotFoundException("This booking does not exist."));
        return BookingResponse.of(cancellations.cancel(me, id, request.toReason()), zone);
    }

    /** Records a sale at the entrance, paid by cash or KHQR. Not checked in yet. */
    @PostMapping("/events/{eventId}/door-sales")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('OWNER')")
    BookingResponse sellAtDoor(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId,
                               @Valid @RequestBody DoorSaleRequest request) {
        return BookingResponse.of(doorSales.sell(me, EventId.parse(eventId), request.toDoorSale()), zone);
    }

    private static BookingSearch search(String query, String status) {
        return new BookingSearch(query, status == null || status.isBlank() ? null : BookingStatus.fromCode(status));
    }
}
