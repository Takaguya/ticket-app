package com.ticket.app.backend.booking.application;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

import com.ticket.app.backend.event.domain.EventKind;
import com.ticket.app.backend.event.domain.SaleStyle;
import org.springframework.stereotype.Component;

/**
 * The {@link SalesRules} for each kind of event, by its {@link SaleStyle}. The server refuses to
 * start when a style has none or two, so a new sale style cannot be added half way.
 */
@Component
class SalesRulesRegistry {

    private final Map<SaleStyle, SalesRules> byStyle = new EnumMap<>(SaleStyle.class);

    SalesRulesRegistry(List<SalesRules> all) {
        for (SalesRules rules : all) {
            if (byStyle.put(rules.style(), rules) != null) {
                throw new IllegalStateException("Two sets of sales rules for " + rules.style());
            }
        }
        for (SaleStyle style : SaleStyle.values()) {
            if (!byStyle.containsKey(style)) {
                throw new IllegalStateException("No sales rules for " + style);
            }
        }
    }

    SalesRules forKind(EventKind kind) {
        return byStyle.get(kind.saleStyle());
    }
}
