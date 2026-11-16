package com.ticket.app.backend.event.domain;

import java.util.List;
import java.util.Objects;

/**
 * What the user app's event page shows beyond what the merchant publishes: more about
 * the venue, a description, the refund policy and a note for each ticket type. Every
 * text may be empty. An event with no page of its own shows {@link #blank}.
 *
 * @param ticketTypeNotes one per ticket type, in the order the owner entered them; a
 *                        missing entry means no note
 */
public record EventPage(EventId eventId, String venueDetail, String about, String policy,
                        List<String> ticketTypeNotes) {

    public EventPage {
        Objects.requireNonNull(eventId, "eventId");
        venueDetail = strip(venueDetail);
        about = strip(about);
        policy = strip(policy);
        ticketTypeNotes = ticketTypeNotes == null ? List.of() : ticketTypeNotes.stream().map(EventPage::strip).toList();
    }

    /** The page of an event nobody has described: nothing to show. */
    public static EventPage blank(EventId eventId) {
        return new EventPage(eventId, "", "", "", List.of());
    }

    /** The note for the ticket type at this position, or an empty one when it has none. */
    public String noteFor(int ticketTypeIndex) {
        return ticketTypeIndex >= 0 && ticketTypeIndex < ticketTypeNotes.size() ? ticketTypeNotes.get(ticketTypeIndex) : "";
    }

    private static String strip(String text) {
        return text == null ? "" : text.strip();
    }
}
