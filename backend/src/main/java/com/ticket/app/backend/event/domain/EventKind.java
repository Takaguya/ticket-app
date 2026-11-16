package com.ticket.app.backend.event.domain;

import java.util.Arrays;
import java.util.Optional;

import com.ticket.app.backend.business.domain.BusinessType;
import com.ticket.app.backend.shared.domain.BusinessRuleException;

/**
 * What kind of event it is. Each kind says how its tickets are sold ({@link #saleStyle()}) and,
 * when it has a publisher of its own, who may publish it and how ({@link #publishing()}).
 *
 * <p>A marathon, a concert and a show are published by an events business with the ordinary
 * form; a marathon asks for the runner's details when booking. A bus trip ({@link BusTrip}), a
 * cinema screening ({@link Screening}) and a place open every day each have their own kind of
 * business and their own form.
 */
public enum EventKind {
    MARATHON("marathon", SaleStyle.TICKETS, null),
    CONCERT("concert", SaleStyle.TICKETS, null),
    SHOW("show", SaleStyle.TICKETS, null),
    BUS("bus", SaleStyle.SEATS, new Publishing(BusinessType.BUS, "bus trips", "bus trip form",
            "A bus company", "bus companies")),
    CINEMA("cinema", SaleStyle.SEATS, new Publishing(BusinessType.CINEMA, "screenings", "screening form",
            "A cinema", "cinemas")),
    ADMISSION("admission", SaleStyle.DAY_PASS, new Publishing(BusinessType.ADMISSION, "places", "place form",
            "An admission business", "admission businesses"));

    /**
     * Who publishes a kind that has its own form, and the words for refusing anyone else.
     *
     * @param businessType the only type of business that publishes it
     * @param plural       what they publish, e.g. "bus trips"
     * @param form         the form they publish it with, e.g. "bus trip form"
     * @param publisher    one of them, e.g. "A bus company"
     * @param publishers   all of them, e.g. "bus companies"
     */
    public record Publishing(BusinessType businessType, String plural, String form, String publisher,
                             String publishers) {
    }

    private final String code;
    private final SaleStyle saleStyle;
    private final Publishing publishing;

    EventKind(String code, SaleStyle saleStyle, Publishing publishing) {
        this.code = code;
        this.saleStyle = saleStyle;
        this.publishing = publishing;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    /** How its tickets are sold. */
    public SaleStyle saleStyle() {
        return saleStyle;
    }

    /** Only a marathon books one runner, whose details the organiser needs. */
    public boolean needsRunnerDetails() {
        return this == MARATHON;
    }

    /**
     * A place is open every day: it has no date of its own, so it never ends, and each booking
     * is for the day the buyer chose.
     */
    public boolean isOpenEveryDay() {
        return saleStyle == SaleStyle.DAY_PASS;
    }

    /** Who publishes it and how, for a kind with a business and a form of its own; empty otherwise. */
    public Optional<Publishing> publishing() {
        return Optional.ofNullable(publishing);
    }

    /** The kind that this type of business publishes with its own form, if it has one. */
    public static Optional<EventKind> ownedBy(BusinessType businessType) {
        return Arrays.stream(values())
                .filter(kind -> kind.publishing != null && kind.publishing.businessType() == businessType)
                .findFirst();
    }

    public static EventKind fromCode(String code) {
        return Arrays.stream(values())
                .filter(kind -> kind.code.equals(code))
                .findFirst()
                .orElseThrow(() -> BusinessRuleException.invalid("Choose what kind of event it is."));
    }
}
