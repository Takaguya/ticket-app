package com.ticket.app.backend.demo;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.booking.model.BookingId;
import com.ticket.app.backend.booking.model.BookingLine;
import com.ticket.app.backend.booking.model.BookingStatus;
import com.ticket.app.backend.booking.model.PaymentMethod;
import com.ticket.app.backend.booking.model.SalesChannel;
import com.ticket.app.backend.business.model.BusinessId;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.EventPage;
import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.Money;

/**
 * The demo's places, open every day: the user app mock's Angkor pass and wildlife centre, run by
 * two admission businesses. Each has visitors booked for the coming days; the wildlife centre's
 * adult tickets (60 a day) sell out tomorrow, to show a daily limit.
 */
final class DemoPlaces {

    /** Angkor Enterprise, an admission business (see {@link DemoMerchants}). */
    static final BusinessId ANGKOR = new BusinessId(UUID.fromString("10000000-0000-7000-8000-000000000008"));
    /** Wildlife Alliance, an admission business. */
    static final BusinessId WILDLIFE = new BusinessId(UUID.fromString("10000000-0000-7000-8000-000000000009"));

    /** How many ticket types of a place have a daily limit is up to it; null is no limit. */
    record Tier(String name, String note, long priceCents, Integer dailyLimit) {

        TicketType toTicketType() {
            return new TicketType(name, Money.ofCents(priceCents), dailyLimit == null ? TicketType.NO_LIMIT : dailyLimit);
        }
    }

    /**
     * @param number     a small number that tells the demo places apart, for booking IDs (1 to 9)
     * @param fullTomorrow how many of the first ticket type tomorrow's bookings take first, so that the
     *                     day's other visitors sell it out or nearly; 0 for none
     */
    record Place(EventId id, int number, BusinessId business, String name, String venue, String detail,
                 String about, String policy, List<Tier> tiers, int fullTomorrow) {

        /** Its date is the day it was published: a placeholder, as for a place published in the app. */
        Event toEvent(LocalDate today, BigDecimal commissionRate, Instant approvedAt) {
            return Event.restore(id, business, name, today.atStartOfDay(), venue,
                    tiers.stream().map(Tier::toTicketType).toList(), commissionRate, approvedAt,
                    EventKind.ADMISSION);
        }

        EventPage toPage() {
            return new EventPage(id, detail, about, policy, tiers.stream().map(Tier::note).toList());
        }
    }

    static final List<Place> ALL = List.of(
            new Place(event(40), 1, ANGKOR, "Angkor Archaeological Park – 1-day pass", "Angkor Ticket Office",
                    "Road 60, Siem Reap",
                    "Access to all temples in the Angkor park for one day, including Angkor Wat, Bayon and Ta "
                            + "Prohm. Valid from 5:00 to sunset on the chosen date.",
                    "Non-refundable · date change allowed once",
                    List.of(new Tier("Adult", "12 years and above", 3700, 2000),
                            new Tier("Child", "Under 12 · ID required", 0, null)), 0),
            new Place(event(41), 2, WILDLIFE, "Phnom Tamao Wildlife Rescue Centre", "Phnom Tamao",
                    "Takeo, 40km from Phnom Penh",
                    "Cambodia's largest wildlife rescue centre, home to elephants, tigers, sun bears and gibbons. "
                            + "Open 08:00–17:00.",
                    "Refundable up to the day before",
                    List.of(new Tier("Adult", "", 500, 60), new Tier("Child", "Under 12", 200, 60)), 58));

    private static final int DAYS = 6;
    private static final int[] PARTY_SIZES = {2, 1, 3, 1, 2, 4, 1, 2};

    private DemoPlaces() {
    }

    /**
     * Online bookings for the coming days, none checked in: some for each of today and the next
     * {@value #DAYS} days, within each ticket type's daily limit. They were made over the days
     * before now.
     */
    static List<Booking> bookings(Place place, LocalDate today, ZoneId zone, Instant now) {
        List<Booking> made = new ArrayList<>();
        for (int day = 0; day <= DAYS; day++) {
            LocalDate visit = today.plusDays(day);
            Map<String, Integer> left = new HashMap<>();
            place.tiers().forEach(tier -> left.put(tier.name(),
                    tier.dailyLimit() == null ? TicketType.NO_LIMIT : tier.dailyLimit()));

            List<List<BookingLine>> parties = new ArrayList<>();
            if (day == 1 && place.fullTomorrow() > 0) {
                // Parties of four adults, then what is left over, so adults are nearly sold out.
                String first = place.tiers().getFirst().name();
                int taken = 0;
                while (taken < place.fullTomorrow()) {
                    int party = Math.min(4, place.fullTomorrow() - taken);
                    parties.add(List.of(new BookingLine(first, party)));
                    taken += party;
                }
            }
            int visitors = 4 + (place.number() + day) % 4;
            for (int i = 0; i < visitors; i++) {
                int size = PARTY_SIZES[(i + day) % PARTY_SIZES.length];
                Tier tier = place.tiers().get((i + place.number()) % place.tiers().size());
                parties.add(List.of(new BookingLine(tier.name(), size)));
            }

            int index = 0;
            for (List<BookingLine> party : parties) {
                BookingLine line = party.getFirst();
                if (left.get(line.ticketType()) < line.quantity()) {
                    continue;
                }
                left.merge(line.ticketType(), -line.quantity(), Integer::sum);
                Tier tier = place.tiers().stream().filter(t -> t.name().equals(line.ticketType())).findFirst()
                        .orElseThrow();
                int person = place.number() * 211 + day * 17 + index;
                // TK, 9 for places, the place's number, the day, the booking's number, 00: 8 digits.
                String id = "TK9%d%d%03d00".formatted(place.number(), day, index);
                made.add(Booking.restore(new BookingId(id), place.id(), DemoTrips.nameOf(person),
                        DemoTrips.phoneOf(person), party, Money.ofCents(tier.priceCents() * line.quantity()),
                        index % 2 == 0 ? PaymentMethod.ABA_KHQR : PaymentMethod.CARD, SalesChannel.ONLINE,
                        BookingStatus.OPEN, List.of(), null, null, null, List.of(), visit,
                        now.minus(Duration.ofHours(6 + (index * 7L + day * 13L) % 140))));
                index++;
            }
        }
        return made;
    }

    private static EventId event(int n) {
        return new EventId(UUID.fromString("30000000-0000-7000-8000-%012d".formatted(n)));
    }
}
