package com.ticket.app.backend.event.controller;

import java.io.IOException;
import java.time.Duration;

import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.event.service.EventImageService;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventImage;
import com.ticket.app.backend.shared.model.NotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The cover image of an event. A business's owner puts and removes the image of its own events;
 * the picture is the request body as it is (a JPEG or PNG up to 5 MB), not JSON or a form, so a
 * phone sends the file straight from the gallery. Anyone, signed in or not, may fetch it by its
 * address, which is in the event's JSON as {@code imageUrl}. (An admin's own endpoints are in the
 * admin module.)
 */
@RestController
class EventImageController {

    private final EventImageService images;

    EventImageController(EventImageService images) {
        this.images = images;
    }

    /** Sets or replaces the image of one of the owner's events. Answers with its new address. */
    @PutMapping("/merchant/events/{eventId}/image")
    @PreAuthorize("hasRole('OWNER')")
    ImageResponse put(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId,
                      HttpServletRequest request) throws IOException {
        EventId id = EventId.parse(eventId);
        EventImage image = images.setByOwner(me, id, readBody(request));
        return ImageResponse.of(image);
    }

    /** Removes the image of one of the owner's events. */
    @DeleteMapping("/merchant/events/{eventId}/image")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('OWNER')")
    void remove(@AuthenticationPrincipal StaffMember me, @PathVariable String eventId) {
        images.removeByOwner(me, EventId.parse(eventId));
    }

    /**
     * The picture. Asked for with the current version in its address ({@code ?v=}, as in
     * {@code imageUrl}) it may be kept for a year, because a new picture has a new address; asked for
     * any other way it must be checked again each time ({@code ETag}, so an unchanged one is not sent twice).
     */
    @GetMapping("/images/events/{eventId}")
    ResponseEntity<byte[]> view(@PathVariable String eventId, @RequestParam(name = "v", required = false) Long version,
                                @RequestHeader(name = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        EventImage image = images.find(EventId.parse(eventId))
                .orElseThrow(() -> new NotFoundException("This event has no image."));
        String etag = "\"" + image.version() + "\"";
        CacheControl cache = version != null && version == image.version()
                ? CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable()
                : CacheControl.noCache().cachePublic();
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).cacheControl(cache).build();
        }
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(image.contentType()))
                .eTag(etag)
                .cacheControl(cache)
                .header("X-Content-Type-Options", "nosniff")
                .body(image.data());
    }

    /** The request body, but never more than one byte past the limit: the service refuses a bigger one. */
    private static byte[] readBody(HttpServletRequest request) throws IOException {
        return request.getInputStream().readNBytes(EventImageService.MAX_UPLOAD_BYTES + 1);
    }

    /** {@code imageUrl} is the address to show it from, e.g. {@code /images/events/<id>?v=1763300000000}. */
    record ImageResponse(String imageUrl) {

        static ImageResponse of(EventImage image) {
            return new ImageResponse(EventImage.urlOf(image.eventId(), image.version()));
        }
    }
}
