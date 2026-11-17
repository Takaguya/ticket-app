package com.ticket.app.backend.booking.controller;

import java.time.Clock;
import java.time.ZoneId;

import com.ticket.app.backend.booking.service.CheckInService;
import com.ticket.app.backend.booking.model.AttemptId;
import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.event.model.EventId;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import com.ticket.app.backend.booking.dto.CheckInRequest;
import com.ticket.app.backend.booking.dto.CheckInResultResponse;

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
