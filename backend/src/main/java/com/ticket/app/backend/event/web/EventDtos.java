package com.ticket.app.backend.event.web;

import java.time.LocalDateTime;
import java.util.List;

import com.ticket.app.backend.event.domain.BusTrip;
import com.ticket.app.backend.event.domain.BusTripDraft;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventDraft;
import com.ticket.app.backend.event.domain.EventId;
import com.ticket.app.backend.event.domain.EventImage;
import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.event.domain.PlaceDraft;
import com.ticket.app.backend.event.domain.Screening;
import com.ticket.app.backend.event.domain.ScreeningDraft;
import com.ticket.app.backend.event.domain.SeatLayout;
import com.ticket.app.backend.event.domain.TicketType;
import com.ticket.app.backend.shared.domain.Money;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/**
 * JSON of the event endpoints, matching the merchant app's Event and TicketType.
 * {@code startsAt} is the local time at the venue, without an offset, e.g.
 * {@code 2026-11-28T06:00:00}. The rules themselves are checked by the domain.
 */
final class EventDtos {

    private EventDtos() {
    }

    /** {@code kind}: marathon, concert or show. */
    record PublishEventRequest(
            String name,
            LocalDateTime startsAt,
            String venue,
            String kind,
            @NotNull(message = "Add at least one ticket type.") List<@NotNull(message = "Fill in every ticket type.") @Valid TicketTypeRequest> ticketTypes) {

        EventDraft toDraft() {
            return new EventDraft(name, startsAt, venue, ticketTypes.stream().map(TicketTypeRequest::toTicketType).toList(),
                    EventKind.fromCode(kind));
        }
    }

    record TicketTypeRequest(
            String name,
            @NotNull(message = "Enter a price for every ticket type (0 for free).") Long priceCents,
            @NotNull(message = "Enter how many tickets of each type are for sale.") Integer quantity) {

        TicketType toTicketType() {
            return new TicketType(name, Money.ofCents(priceCents), quantity);
        }
    }

    /**
     * What the owner of a bus company fills in to publish a trip. {@code startsAt} is when the
     * bus leaves; {@code coachType} is seater, vip or sleeper; {@code priceCents} is per seat.
     * {@code boardingAddress}, {@code about} and {@code amenities} are optional.
     */
    record PublishBusTripRequest(
            String origin,
            String destination,
            LocalDateTime startsAt,
            Integer durationMinutes,
            String coachType,
            @NotNull(message = "Enter the price of a seat (0 for free).") Long priceCents,
            String boardingPoint,
            String boardingAddress,
            String about,
            List<String> amenities) {

        BusTripDraft toDraft() {
            return new BusTripDraft(origin, destination, startsAt, durationMinutes == null ? 0 : durationMinutes,
                    SeatLayout.coachFromCode(coachType), Money.ofCents(priceCents), boardingPoint, boardingAddress,
                    about, amenities);
        }
    }

    /**
     * What the owner of a cinema fills in to publish a screening. {@code startsAt} is when the film
     * starts; {@code hallSize} is small, standard or large; {@code priceCents} is per seat. {@code
     * rating}, {@code genre}, {@code about} and {@code theatreArea} are optional. {@code theatre} is
     * the cinema or branch the buyers see, e.g. "Legend Cinema, Aeon Mall".
     */
    record PublishScreeningRequest(
            String filmTitle,
            String rating,
            String genre,
            Integer runtimeMinutes,
            String about,
            String theatre,
            String theatreArea,
            String hall,
            String hallSize,
            LocalDateTime startsAt,
            @NotNull(message = "Enter the price of a seat (0 for free).") Long priceCents) {

        ScreeningDraft toDraft() {
            return new ScreeningDraft(filmTitle, rating, genre, runtimeMinutes == null ? 0 : runtimeMinutes, about,
                    theatre, theatreArea, hall, SeatLayout.hallFromCode(hallSize), startsAt, Money.ofCents(priceCents));
        }
    }

    /**
     * What the owner of an admission business fills in to publish a place that is open every day.
     * {@code venueDetail} (where it is), {@code about} and {@code policy} are optional. Each ticket
     * type has a {@code priceCents} and an optional {@code dailyLimit}: the most sold for one day,
     * none when left out.
     */
    record PublishPlaceRequest(
            String name,
            String venue,
            String venueDetail,
            String about,
            String policy,
            List<@NotNull(message = "Fill in every ticket type.") @Valid PlaceTicketRequest> ticketTypes) {

        PlaceDraft toDraft() {
            return new PlaceDraft(name, venue, venueDetail, about, policy, ticketTypes == null ? List.of()
                    : ticketTypes.stream().map(PlaceTicketRequest::toTicket).toList());
        }
    }

    record PlaceTicketRequest(
            String name,
            String description,
            @NotNull(message = "Enter the price of every ticket type (0 for free).") Long priceCents,
            Integer dailyLimit) {

        PlaceDraft.PlaceTicket toTicket() {
            return new PlaceDraft.PlaceTicket(name, description, Money.ofCents(priceCents), dailyLimit);
        }
    }

    /**
     * {@code approved} is false while the event waits for a Pin admin; it cannot be sold until then.
     * {@code kind}: marathon, concert, show, bus, cinema or admission. {@code bus} is set for a bus trip only,
     * {@code screening} for a cinema screening only. {@code imageUrl} is the cover image's address on this
     * server (e.g. {@code /images/events/<id>?v=1763300000000}), or null when the event has none.
     */
    record EventResponse(String id, String name, LocalDateTime startsAt, String venue, double commissionRate,
                         int capacity, boolean approved, String kind, List<TicketTypeResponse> ticketTypes,
                         BusJson bus, ScreeningResponse screening, String imageUrl) {

        static EventResponse of(Event event) {
            return of(event, null, null);
        }

        static EventResponse of(Event event, BusTrip trip, Screening screening) {
            return new EventResponse(event.id().toString(), event.name(), event.startsAt(), event.venue(),
                    event.commissionRate().doubleValue(), event.capacity(), event.isApproved(), event.kind().code(),
                    event.ticketTypes().stream().map(TicketTypeResponse::of).toList(), BusJson.of(trip),
                    ScreeningResponse.of(screening), null);
        }

        /** This response with the address of the event's cover image, from {@link EventImage#version()}. */
        EventResponse withImageVersion(Long version) {
            return new EventResponse(id, name, startsAt, venue, commissionRate, capacity, approved, kind, ticketTypes,
                    bus, screening, EventImage.urlOf(EventId.parse(id), version));
        }
    }

    /** {@code hallSize}: small, standard or large; {@code hallLabel} reads like "Standard hall · 80 seats". */
    record ScreeningResponse(String filmTitle, String rating, String genre, int runtimeMinutes, String hall,
                             String hallSize, String hallLabel, int seats) {

        /** Null for an event that is not a screening. */
        static ScreeningResponse of(Screening screening) {
            return screening == null ? null : new ScreeningResponse(screening.filmTitle(), screening.rating(),
                    screening.genre(), screening.runtimeMinutes(), screening.hall(), screening.layout().code(),
                    screening.layout().label(), screening.capacity());
        }
    }

    /** {@code coachType}: seater, vip or sleeper; {@code coachLabel} is how buyers see it, e.g. "Seater · 2+2". */
    record BusJson(String origin, String destination, int durationMinutes, String coachType, String coachLabel,
                   int seats, List<String> amenities) {

        /** Null for an event that is not a bus trip. */
        static BusJson of(BusTrip trip) {
            return trip == null ? null : new BusJson(trip.origin(), trip.destination(), trip.durationMinutes(),
                    trip.layout().code(), trip.layout().label(), trip.capacity(), trip.amenities());
        }
    }

    record TicketTypeResponse(String name, long priceCents, int quantity) {

        static TicketTypeResponse of(TicketType type) {
            return new TicketTypeResponse(type.name(), type.price().cents(), type.quantity());
        }
    }
}
