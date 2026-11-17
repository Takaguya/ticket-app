package com.ticket.app.backend.booking.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

import com.ticket.app.backend.booking.model.Booking;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.business.model.BusinessType;
import com.ticket.app.backend.event.service.EventOnSale;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventKind;
import com.ticket.app.backend.event.model.SaleStyle;
import org.junit.jupiter.api.Test;

/**
 * Every kind of event sells by one of a few styles, and each style has exactly one set of rules.
 * Adding a kind with a style that exists needs no new booking code; adding a style needs rules, or
 * the server does not start.
 */
class SalesRulesRegistryTest {

    /** A stand-in for the rules of a style: only which style it is matters here. */
    private record Stub(SaleStyle style) implements SalesRules {

        @Override
        public PreparedSale online(Buyer buyer, OnlineOrder order, EventOnSale onSale, Instant now) {
            throw new UnsupportedOperationException();
        }

        @Override
        public PreparedSale door(Event event, DoorSale sale, Instant now) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Booking> summaryBookings(Event event) {
            throw new UnsupportedOperationException();
        }
    }

    private static List<SalesRules> everyStyle() {
        return Arrays.stream(SaleStyle.values()).<SalesRules>map(Stub::new).toList();
    }

    @Test
    void everyKindOfEventFindsTheRulesOfItsSaleStyle() {
        SalesRulesRegistry registry = new SalesRulesRegistry(everyStyle());

        for (EventKind kind : EventKind.values()) {
            assertThat(registry.forKind(kind).style()).as(kind.code()).isEqualTo(kind.saleStyle());
        }
    }

    @Test
    void theRealRulesCoverEveryStyleOnce() {
        // The three real rules classes, as Spring wires them: no style is left out or doubled.
        List<SaleStyle> styles = List.of(
                new PlaceSalesRules(null, null).style(),
                new SeatSalesRules(null, null).style(),
                new TicketSalesRules(null, null).style());

        assertThat(styles).containsExactlyInAnyOrder(SaleStyle.values());
    }

    @Test
    void aStyleWithoutRulesStopsTheServerFromStarting() {
        List<SalesRules> missingOne = everyStyle().stream()
                .filter(rules -> rules.style() != SaleStyle.SEATS)
                .toList();

        assertThatThrownBy(() -> new SalesRulesRegistry(missingOne))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("No sales rules for SEATS");
    }

    @Test
    void twoSetsOfRulesForOneStyleStopTheServerFromStarting() {
        List<SalesRules> twice = new java.util.ArrayList<>(everyStyle());
        twice.add(new Stub(SaleStyle.DAY_PASS));

        assertThatThrownBy(() -> new SalesRulesRegistry(twice))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Two sets of sales rules for DAY_PASS");
    }

    @Test
    void aKindWithItsOwnFormNamesItsPublisherAndEachBusinessTypeOwnsAtMostOne() {
        for (EventKind kind : EventKind.values()) {
            kind.publishing().ifPresent(own ->
                    assertThat(EventKind.ownedBy(own.businessType())).as(kind.code()).contains(kind));
        }
        // An events business publishes the ordinary kinds with the ordinary form: it owns none.
        assertThat(EventKind.ownedBy(BusinessType.EVENTS)).isEmpty();
        assertThat(EventKind.ownedBy(BusinessType.BUS)).contains(EventKind.BUS);
        assertThat(EventKind.ownedBy(BusinessType.CINEMA)).contains(EventKind.CINEMA);
        assertThat(EventKind.ownedBy(BusinessType.ADMISSION)).contains(EventKind.ADMISSION);
        assertThat(EventKind.MARATHON.publishing()).isEmpty();
    }
}
