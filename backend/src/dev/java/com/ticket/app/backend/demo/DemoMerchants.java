package com.ticket.app.backend.demo;

import static com.ticket.app.backend.demo.SampleData.type;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.ticket.app.backend.business.domain.BusinessId;
import com.ticket.app.backend.business.domain.BusinessStatus;
import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.business.domain.StaffId;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.event.domain.EventPage;
import com.ticket.app.backend.event.domain.TicketType;

/**
 * The demo's other businesses, as in the admin panel's design: three more active
 * ones, two waiting for approval and a suspended one. Their events are dated around
 * today; those of the businesses waiting for approval wait too.
 */
final class DemoMerchants {

    record Merchant(BusinessId id, String name, BusinessType type, String joinCode, BusinessStatus status,
                    StaffId ownerId, String ownerName, String ownerPhone, List<DemoEvent> events) {
    }

    /**
     * @param bookings online bookings to make, none checked in; 0 for none
     */
    record DemoEvent(EventId id, String name, EventKind kind, String venue, int daysFromToday, LocalTime startsAt,
                     boolean approved, List<TicketType> ticketTypes, int bookings, long seed) {

        Event toEvent(BusinessId business, LocalDate today, BigDecimal commissionRate, Instant approvedAt) {
            return Event.restore(id, business, name, today.plusDays(daysFromToday).atTime(startsAt), venue,
                    ticketTypes, commissionRate, approved ? approvedAt : null, kind);
        }
    }

    /** Garden City's place, waiting for approval. */
    static final EventId GARDEN_CITY_PLACE = event(18);

    static final List<Merchant> ALL = List.of(
            new Merchant(business(2), "PP Live Events", BusinessType.EVENTS, "615204", BusinessStatus.ACTIVE,
                    owner(12), "Sophea Lim", "+85510771230", List.of(
                    new DemoEvent(event(12), "Khmer Rock Night 2026", EventKind.CONCERT, "Koh Pich Theatre", 11, LocalTime.of(19, 0),
                            true, List.of(type("Standard", 1500, 250), type("Front zone", 2500, 100),
                            type("VIP", 3500, 50)), 50, 4401))),
            // Its screenings are in DemoScreenings: a cinema sells seats at screenings, not events.
            new Merchant(business(3), "Legend Cinema", BusinessType.CINEMA, "739581", BusinessStatus.ACTIVE,
                    owner(13), "Rithy Heng", "+85515300418", List.of()),
            // Its trips are in DemoTrips: a bus company sells seats on trips, not events.
            new Merchant(business(4), "Giant Ibis", BusinessType.BUS, "284716", BusinessStatus.ACTIVE,
                    owner(14), "Dara Chea", "+85517905662", List.of()),
            new Merchant(business(5), "Siem Reap Arts Collective", BusinessType.EVENTS, "902731",
                    BusinessStatus.PENDING, owner(15), "Chenda Ouk", "+85592114507", List.of(
                    new DemoEvent(event(17), "Angkor Sunset Music Fest", EventKind.CONCERT, "Angkor Eye Field, Siem Reap", 63,
                            LocalTime.of(16, 0), false, List.of(type("General", 2000, 1200),
                            type("Front zone", 4000, 250), type("VIP", 8000, 50)), 0, 0))),
            // A place, open every day: its date is a placeholder, the day it was published.
            new Merchant(business(6), "Garden City", BusinessType.ADMISSION, "357048", BusinessStatus.PENDING,
                    owner(16), "Visal Tep", "+85511640388", List.of(
                    new DemoEvent(GARDEN_CITY_PLACE, "Garden City Water Park Day Pass", EventKind.ADMISSION,
                            "Garden City, Phnom Penh", 0, LocalTime.of(0, 0), false,
                            List.of(type("Adult", 1000, 300), type("Child", 600, 200),
                            type("Family of four", 2800, 50)), 0, 0))),
            new Merchant(business(7), "Laugh PP", BusinessType.EVENTS, "518362", BusinessStatus.SUSPENDED,
                    owner(17), "Makara Ros", "+85516258941", List.of(
                    new DemoEvent(event(19), "Laugh PP: Stand-up Comedy Night", EventKind.SHOW, "Factory Phnom Penh", 14,
                            LocalTime.of(20, 0), true, List.of(type("Standard", 800, 80), type("Front row", 1200, 30),
                            type("Table for two", 2000, 10)), 20, 7701))),
            // Their places are in DemoPlaces: an admission business sells days at a place, not events.
            new Merchant(business(8), "Angkor Enterprise", BusinessType.ADMISSION, "471926", BusinessStatus.ACTIVE,
                    owner(18), "Pisey Sok", "+85516420731", List.of()),
            new Merchant(business(9), "Wildlife Alliance", BusinessType.ADMISSION, "836205", BusinessStatus.ACTIVE,
                    owner(19), "Srey Neang", "+85578315940", List.of()));

    /**
     * What the user app's event page shows for the events of {@link #ALL} that have one,
     * as the app's own mock describes them. The others show blanks.
     */
    private static final Map<EventId, EventPage> PAGES = Map.of(
            event(12), new EventPage(event(12), "Diamond Island, Phnom Penh",
                    "Five Cambodian rock bands on one stage for a single night. Doors open 18:00, show starts "
                            + "19:00. All ages, standing floor for the standard ticket.",
                    "Refundable up to 48h before the show",
                    List.of("Standing floor", "Closest to the stage", "Seated balcony · free drink")),
            event(17), new EventPage(event(17), "Charles de Gaulle Rd, Siem Reap",
                    "Open-air festival with 12 acts across two stages, food village and night market. Gates "
                            + "open 16:00.",
                    "Refundable up to 7 days before",
                    List.of("All stages", "Closest to the stage", "Lounge, viewing deck, fast lane")),
            event(19), new EventPage(event(19), "#1159 National Rd 2, Phnom Penh",
                    "Six comedians, Khmer and English sets, 90 minutes. 18+ only.",
                    "Refundable up to 24h before",
                    List.of("Free seating", "Front-of-room seats", "Front tables · 2 drinks")),
            GARDEN_CITY_PLACE, new EventPage(GARDEN_CITY_PLACE, "Chroy Changvar, Phnom Penh",
                    "Full-day access to all slides, wave pool and lazy river. Lockers and towels available on "
                            + "site.",
                    "Refundable up to the day before",
                    List.of("Above 140cm", "90–140cm", "2 adults and 2 children")));

    private DemoMerchants() {
    }

    /** The page of a demo event, if it has one. */
    static Optional<EventPage> pageOf(EventId event) {
        return Optional.ofNullable(PAGES.get(event));
    }

    private static BusinessId business(int n) {
        return new BusinessId(UUID.fromString("10000000-0000-7000-8000-%012d".formatted(n)));
    }

    private static StaffId owner(int n) {
        return new StaffId(UUID.fromString("20000000-0000-7000-8000-%012d".formatted(n)));
    }

    private static EventId event(int n) {
        return new EventId(UUID.fromString("30000000-0000-7000-8000-%012d".formatted(n)));
    }
}
