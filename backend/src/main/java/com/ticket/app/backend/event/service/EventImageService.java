package com.ticket.app.backend.event.service;

import java.time.Clock;
import java.time.temporal.ChronoUnit;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;

import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventImage;
import com.ticket.app.backend.event.repository.EventImageRepository;
import com.ticket.app.backend.event.repository.EventRepository;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Cover images of events, bus trips, screenings and places. A business's owner sets, changes and
 * removes the image of its own events; a Pin admin may do the same for any event, to replace or
 * take down one that should not be shown. Scanners cannot. Anyone may see an image (the apps
 * fetch them without signing in), but only through the address of the event it belongs to.
 *
 * <p>An upload is never stored as it came: see {@link ImageNormalizer}.
 */
@Service
public class EventImageService {

    /** The biggest upload accepted, in bytes; anything past it is not read. */
    public static final int MAX_UPLOAD_BYTES = ImageNormalizer.MAX_UPLOAD_BYTES;

    private final EventImageRepository images;
    private final EventRepository events;
    private final EventService eventsOfBusiness;
    private final Clock clock;

    public EventImageService(EventImageRepository images, EventRepository events, EventService eventsOfBusiness,
                             Clock clock) {
        this.images = images;
        this.events = events;
        this.eventsOfBusiness = eventsOfBusiness;
        this.clock = clock;
    }

    /**
     * Sets the image of one of the owner's own events, replacing the earlier one. Not found when
     * the event is another business's.
     *
     * @param upload the picture as uploaded: JPEG or PNG, up to 5 MB
     */
    @Transactional
    public EventImage setByOwner(StaffMember owner, EventId eventId, byte[] upload) {
        requireOwner(owner);
        eventsOfBusiness.eventOf(owner, eventId);
        return store(eventId, upload);
    }

    /** Removes the image of one of the owner's own events; nothing happens when it has none. */
    @Transactional
    public void removeByOwner(StaffMember owner, EventId eventId) {
        requireOwner(owner);
        eventsOfBusiness.eventOf(owner, eventId);
        images.delete(eventId);
    }

    /** Sets the image of any event, for an admin. */
    @Transactional
    public EventImage setByAdmin(EventId eventId, byte[] upload) {
        requireExists(eventId);
        return store(eventId, upload);
    }

    /** Removes the image of any event, for an admin. */
    @Transactional
    public void removeByAdmin(EventId eventId) {
        requireExists(eventId);
        images.delete(eventId);
    }

    /** The event's image with its bytes; empty when it has none. */
    public Optional<EventImage> find(EventId eventId) {
        return images.find(eventId);
    }

    /** The version of each of these events' images, in one query; events with no image are left out. */
    public Map<EventId, Long> versionsOf(Collection<EventId> eventIds) {
        return images.findVersions(eventIds);
    }

    private EventImage store(EventId eventId, byte[] upload) {
        byte[] picture = ImageNormalizer.normalize(upload);
        // Whole milliseconds: the version in the address is the same before and after the database.
        EventImage image = new EventImage(eventId, ImageNormalizer.CONTENT_TYPE, picture,
                clock.instant().truncatedTo(ChronoUnit.MILLIS));
        images.save(image);
        return image;
    }

    private void requireExists(EventId eventId) {
        if (events.find(eventId).isEmpty()) {
            throw new NotFoundException("This event does not exist.");
        }
    }

    private static void requireOwner(StaffMember member) {
        if (!member.isOwner()) {
            throw BusinessRuleException.conflict("Only the business owner can change an event's picture.");
        }
    }
}
