package com.ticket.app.backend.event.domain;

import java.util.Locale;
import java.util.Objects;

import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * What makes an event a cinema screening: a film shown in a hall. The event's name is the
 * film, its venue the cinema and its start the show time. The hall's size decides the seats.
 * Its only ticket type is {@link BusTrip#SEAT_TICKET}, a seat.
 *
 * @param rating  e.g. PG-13; may be empty
 * @param genre   e.g. Action, or a language such as Khmer; may be empty
 * @param hall    e.g. "Hall 3"
 */
public record Screening(EventId eventId, String filmTitle, String rating, String genre, int runtimeMinutes,
                        String hall, SeatLayout layout) {

    public Screening {
        Objects.requireNonNull(eventId, "eventId");
        filmTitle = filmTitle == null ? "" : filmTitle.strip();
        rating = rating == null ? "" : rating.strip();
        genre = genre == null ? "" : genre.strip();
        hall = hall == null ? "" : hall.strip();
        if (filmTitle.length() < 2) {
            throw BusinessRuleException.invalid("Enter the film's title.");
        }
        if (filmTitle.length() > 100) {
            throw BusinessRuleException.invalid("Keep the film's title under 100 characters.");
        }
        if (slug(filmTitle).isEmpty()) {
            // The title names the film in the app: it needs at least one letter or digit.
            throw BusinessRuleException.invalid("The film's title needs letters or digits.");
        }
        if (rating.length() > 10) {
            throw BusinessRuleException.invalid("Keep the rating under 10 characters.");
        }
        if (genre.length() > 30) {
            throw BusinessRuleException.invalid("Keep the genre under 30 characters.");
        }
        if (runtimeMinutes < 10 || runtimeMinutes > 600) {
            throw BusinessRuleException.invalid("The film runs between 10 minutes and 10 hours.");
        }
        if (hall.isEmpty()) {
            throw BusinessRuleException.invalid("Enter the hall, e.g. Hall 3.");
        }
        if (hall.length() > 40) {
            throw BusinessRuleException.invalid("Keep the hall's name under 40 characters.");
        }
        if (layout == null || !layout.isHall()) {
            throw BusinessRuleException.invalid("Choose the size of the hall.");
        }
    }

    /** The film's name as the user app knows it: {@code neak-ta-the-guardian}. Same title, same film. */
    public String filmId() {
        return slug(filmTitle);
    }

    /**
     * The film's id for a title: letters, marks and digits of any script, in lower case, with
     * dashes between the rest. A Khmer title keeps its Khmer letters; ASCII-only would reduce it to
     * nothing and make different films one.
     */
    public static String slug(String title) {
        return title.strip().toLowerCase(Locale.ROOT).replaceAll("[^\\p{L}\\p{M}\\p{N}]+", "-")
                .replaceAll("^-|-$", "");
    }

    /** The hall's total number of seats. */
    public int capacity() {
        return layout.capacity();
    }
}
