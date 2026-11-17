package com.ticket.app.backend.booking.model;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.List;

import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.shared.model.Money;

/**
 * The numbers behind the Today and Finance screens for one event.
 *
 * <p>Rules: cancelled bookings count for nothing. Commission is a percentage of
 * online sales only. The business receives the revenue minus commission. Revenue counts
 * the tickets' full price: Pin pays for promo codes, so a discount does not reduce it.
 */
public record SalesSummary(
        int capacity,
        int sold,
        int checkedIn,
        int bookingCount,
        Money online,
        Money door,
        Money commission,
        BigDecimal commissionRate,
        List<TicketTypeSales> byTicketType) {

    /** Sold and checked-in tickets of one ticket type, against its quantity for sale. */
    public record TicketTypeSales(String name, int quantity, int sold, int checkedIn) {

        public int left() {
            return Math.max(0, quantity - sold);
        }
    }

    public SalesSummary {
        byTicketType = List.copyOf(byTicketType);
    }

    public static SalesSummary of(Event event, Collection<Booking> bookings) {
        List<Booking> counted = bookings.stream().filter(b -> b.isFor(event.id()) && b.countsAsSold()).toList();
        List<Booking> admitted = counted.stream().filter(b -> b.status() == BookingStatus.CHECKED_IN).toList();

        List<TicketTypeSales> byType = event.ticketTypes().stream()
                .map(type -> new TicketTypeSales(
                        type.name(),
                        type.quantity(),
                        counted.stream().mapToInt(b -> b.quantityOf(type.name())).sum(),
                        admitted.stream().mapToInt(b -> b.quantityOf(type.name())).sum()))
                .toList();

        return new SalesSummary(
                event.capacity(),
                tickets(counted),
                tickets(admitted),
                counted.size(),
                total(counted, SalesChannel.ONLINE),
                total(counted, SalesChannel.DOOR),
                counted.stream().map(b -> b.commission(event.commissionRate())).reduce(Money.ZERO, Money::plus),
                event.commissionRate(),
                byType);
    }

    public Money revenue() {
        return online.plus(door);
    }

    /** What the business receives. */
    public Money net() {
        return revenue().minus(commission);
    }

    /** Tickets that can still be sold. Door sales stop at 0. */
    public int left() {
        return Math.max(0, capacity - sold);
    }

    /** Tickets of one type that can still be sold; 0 for a type the event does not have. */
    public int leftOf(String ticketType) {
        return byTicketType.stream()
                .filter(type -> type.name().equals(ticketType))
                .mapToInt(TicketTypeSales::left)
                .findFirst()
                .orElse(0);
    }

    private static int tickets(List<Booking> bookings) {
        return bookings.stream().mapToInt(Booking::ticketCount).sum();
    }

    private static Money total(List<Booking> bookings, SalesChannel channel) {
        return bookings.stream()
                .filter(b -> b.channel() == channel)
                .map(Booking::subtotal)
                .reduce(Money.ZERO, Money::plus);
    }
}
