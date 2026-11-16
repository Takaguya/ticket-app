package com.ticket.app.backend.booking.web;

import java.time.Clock;
import java.time.ZoneId;

import com.ticket.app.backend.booking.application.CheckInService;
import com.ticket.app.backend.booking.domain.AttemptId;
import com.ticket.app.backend.booking.web.BookingDtos.CheckInRequest;
import com.ticket.app.backend.booking.web.BookingDtos.CheckInResultResponse;
import com.ticket.app.backend.business.domain.StaffMember;
import com.ticket.app.backend.event.domain.EventId;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/** Scanning tickets at the entrance. Owners and scanners. */
@RestController
class CheckInController {

    private final CheckInService checkIns;
    private final ZoneId zone;

    CheckInController(CheckInService checkIns, Clock clock) {
        this.checkIns = checkIns;
        this.zone = clock.getZone();
    }

    /**
     * Answers with one of the five scan results. Check-in that is not open (the
     * event is upcoming or over) is refused with 409.
     */
    @PostMapping("/merchant/checkins")
    CheckInResultResponse checkIn(@AuthenticationPrincipal StaffMember me, @Valid @RequestBody CheckInRequest request) {
        return CheckInResultResponse.of(checkIns.checkIn(me, EventId.parse(request.eventId()), request.code(),
                AttemptId.parseOptional(request.attemptId())), zone);
    }
}
