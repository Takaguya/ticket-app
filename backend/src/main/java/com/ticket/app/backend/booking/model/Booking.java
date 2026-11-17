package com.ticket.app.backend.booking.model;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import com.ticket.app.backend.business.model.StaffMember;
import com.ticket.app.backend.buyer.model.Buyer;
import com.ticket.app.backend.buyer.model.BuyerId;
import com.ticket.app.backend.event.model.BusTrip;
import com.ticket.app.backend.event.model.Event;
import com.ticket.app.backend.event.model.EventId;
import com.ticket.app.backend.event.model.SeatLayout;
import com.ticket.app.backend.event.model.TicketType;
import com.ticket.app.backend.shared.model.BusinessRuleException;
import com.ticket.app.backend.shared.model.Money;
import com.ticket.app.backend.shared.model.PhoneNumber;

/**
 * One purchase. Both apps share it: the user app sells online, the merchant app
 * sells at the door and checks guests in. A booking is admitted as a whole.
 */
public final class Booking {

    /** The buyer name of a door sale, where only a phone number is asked. */
    public static final String WALK_IN_GUEST = "Walk-in guest";

    /** Most tickets one door sale may hold, as in the merchant prototype. */
    public static final int MAX_TICKETS_PER_DOOR_SALE = 8;

    /** Most tickets one booking in the Pin app may hold, as in the user app's prototype. */
    public static final int MAX_TICKETS_PER_ONLINE_BOOKING = 8;

    private static final DateTimeFormatter VISIT_DAY = DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH);

    private final BookingId id;
    private final EventId eventId;
    private final String buyerName;
    private final PhoneNumber phone;
    private final List<BookingLine> lines;
    private final Money total;
    private final PaymentMethod payment;
    private final SalesChannel channel;
    private final List<String> tshirtSizes;
    private final Instant createdAt;
    /** Set when it was bought in the Pin app; null for door sales and the demo's sample bookings. */
    private final OnlinePurchase purchase;
    /** The seats of a bus trip, one per ticket; empty for any other event. They stay after a cancellation. */
    private final List<SeatBooking> seats;
    /** The day a place's tickets are good for; null for any other event. */
    private final LocalDate visitDate;
    private BookingStatus status;
    private CheckIn checkIn;
    /** Set when the business cancelled it; bookings cancelled before this was recorded have none. */
    private Cancellation cancellation;

    private Booking(BookingId id, EventId eventId, String buyerName, PhoneNumber phone, List<BookingLine> lines,
                    Money total, PaymentMethod payment, SalesChannel channel, BookingStatus status,
                    List<String> tshirtSizes, CheckIn checkIn, Cancellation cancellation, OnlinePurchase purchase,
                    List<SeatBooking> seats, LocalDate visitDate, Instant createdAt) {
        this.id = Objects.requireNonNull(id, "id");
        this.eventId = Objects.requireNonNull(eventId, "eventId");
        this.buyerName = Objects.requireNonNull(buyerName, "buyerName");
        this.phone = Objects.requireNonNull(phone, "phone");
        this.lines = List.copyOf(lines);
        this.total = Objects.requireNonNull(total, "total");
        this.payment = Objects.requireNonNull(payment, "payment");
        this.channel = Objects.requireNonNull(channel, "channel");
        this.status = Objects.requireNonNull(status, "status");
        this.tshirtSizes = List.copyOf(tshirtSizes);
        this.checkIn = checkIn;
        this.cancellation = cancellation;
        this.purchase = purchase;
        this.seats = List.copyOf(seats);
        this.visitDate = visitDate;
        this.createdAt = Objects.requireNonNull(createdAt, "createdAt");
        if ((status == BookingStatus.CHECKED_IN) != (checkIn != null)) {
            throw new IllegalArgumentException("A booking has a check-in exactly when it is checked in");
        }
        if (cancellation != null && status != BookingStatus.CANCELLED) {
            throw new IllegalArgumentException("Only a cancelled booking has a cancellation");
        }
        if (purchase != null && channel != SalesChannel.ONLINE) {
            throw new IllegalArgumentException("Only an online booking has an online purchase");
        }
        if (!this.seats.isEmpty() && this.seats.size() != ticketCount()) {
            throw new IllegalArgumentException("A booking holds one seat per ticket, or none");
        }
    }

    /**
     * A booking read back from storage.
     *
     * @param visitDate the day a place's tickets are good for; null for any other event
     */
    public static Booking restore(BookingId id, EventId eventId, String buyerName, PhoneNumber phone,
                                  List<BookingLine> lines, Money total, PaymentMethod payment, SalesChannel channel,
                                  BookingStatus status, List<String> tshirtSizes, CheckIn checkIn,
                                  Cancellation cancellation, OnlinePurchase purchase, List<SeatBooking> seats,
                                  LocalDate visitDate, Instant createdAt) {
        return new Booking(id, eventId, buyerName, phone, lines, total, payment, channel, status, tshirtSizes,
                checkIn, cancellation, purchase, seats, visitDate, createdAt);
    }

    /** A booking read back from storage that is not for a place's visit day. */
    public static Booking restore(BookingId id, EventId eventId, String buyerName, PhoneNumber phone,
                                  List<BookingLine> lines, Money total, PaymentMethod payment, SalesChannel channel,
                                  BookingStatus status, List<String> tshirtSizes, CheckIn checkIn,
                                  Cancellation cancellation, OnlinePurchase purchase, List<SeatBooking> seats,
                                  Instant createdAt) {
        return restore(id, eventId, buyerName, phone, lines, total, payment, channel, status, tshirtSizes, checkIn,
                cancellation, purchase, seats, null, createdAt);
    }

    /** A booking that holds no seats: any event but a bus trip. */
    public static Booking restore(BookingId id, EventId eventId, String buyerName, PhoneNumber phone,
                                  List<BookingLine> lines, Money total, PaymentMethod payment, SalesChannel channel,
                                  BookingStatus status, List<String> tshirtSizes, CheckIn checkIn,
                                  Cancellation cancellation, OnlinePurchase purchase, Instant createdAt) {
        return restore(id, eventId, buyerName, phone, lines, total, payment, channel, status, tshirtSizes, checkIn,
                cancellation, purchase, List.of(), createdAt);
    }

    /** A booking with no online purchase details, such as a door sale or the demo's sample bookings. */
    public static Booking restore(BookingId id, EventId eventId, String buyerName, PhoneNumber phone,
                                  List<BookingLine> lines, Money total, PaymentMethod payment, SalesChannel channel,
                                  BookingStatus status, List<String> tshirtSizes, CheckIn checkIn,
                                  Cancellation cancellation, Instant createdAt) {
        return restore(id, eventId, buyerName, phone, lines, total, payment, channel, status, tshirtSizes, checkIn,
                cancellation, null, createdAt);
    }

    /** A booking with no cancellation details either, such as the demo's. */
    public static Booking restore(BookingId id, EventId eventId, String buyerName, PhoneNumber phone,
                                  List<BookingLine> lines, Money total, PaymentMethod payment, SalesChannel channel,
                                  BookingStatus status, List<String> tshirtSizes, CheckIn checkIn, Instant createdAt) {
        return restore(id, eventId, buyerName, phone, lines, total, payment, channel, status, tshirtSizes, checkIn,
                null, null, createdAt);
    }

    /**
     * A sale at the entrance, paid by cash or KHQR, of 1 to 8 tickets. The price comes
     * from the event's ticket types. Refused when the event, or one of the ticket
     * types, has fewer tickets left than asked for.
     *
     * @param sales the event's sales so far, for what is left
     */
    public static Booking soldAtDoor(BookingId id, Event event, List<BookingLine> lines, PhoneNumber buyerPhone,
                                     PaymentMethod payment, SalesSummary sales, Instant now) {
        return soldAtDoor(id, event, lines, buyerPhone, payment, sales, List.of(), now);
    }

    /**
     * A door sale for a bus trip: one of the coach's seats per ticket, the ones the caller
     * found free, as plain taken seats.
     *
     * @param seats the seat of each ticket; empty for any other event
     */
    public static Booking soldAtDoor(BookingId id, Event event, List<BookingLine> lines, PhoneNumber buyerPhone,
                                     PaymentMethod payment, SalesSummary sales, List<String> seats, Instant now) {
        return soldAtDoor(id, event, lines, buyerPhone, payment, sales, seats, null, now);
    }

    /**
     * A door sale. At a place the tickets are good for the day of the sale: {@code visitDate}
     * is today, and {@code sales} counts that day's sales only.
     *
     * @param visitDate today for a place; null for any other event
     */
    public static Booking soldAtDoor(BookingId id, Event event, List<BookingLine> lines, PhoneNumber buyerPhone,
                                     PaymentMethod payment, SalesSummary sales, List<String> seats,
                                     LocalDate visitDate, Instant now) {
        if (!payment.isAcceptedAtDoor()) {
            throw BusinessRuleException.invalid("Door sales are paid by cash or KHQR.");
        }
        List<BookingLine> wanted = lines == null ? List.of() : List.copyOf(lines);
        Money total = priced(event, wanted, sales, MAX_TICKETS_PER_DOOR_SALE, "Maximum "
                + MAX_TICKETS_PER_DOOR_SALE + " tickets per sale.");

        return new Booking(id, event.id(), WALK_IN_GUEST, buyerPhone, wanted, total, payment, SalesChannel.DOOR,
                BookingStatus.OPEN, List.of(), null, null, null,
                seats.stream().map(seat -> new SeatBooking(seat, null)).toList(), visitDate, now);
    }

    /**
     * A purchase in the Pin app, paid by KHQR or card, of 1 to 8 tickets. The price comes
     * from the event's ticket types, less the promo code's discount. A race holds one
     * ticket and needs its runner; for any other event the runner is dropped. Refused when the event, or one
     * of the ticket types, has fewer tickets left than asked for. The caller makes sure
     * the event is on sale and holds it while the booking is saved.
     *
     * <p>Paying is simulated: Pin takes no real money yet.
     *
     * @param needsRunner whether the event is a race, which needs the runner's details
     * @param promoCode   as typed; null or blank for none
     * @param sales       the event's sales so far, for what is left
     */
    public static Booking boughtOnline(BookingId id, Event event, boolean needsRunner, Buyer buyer,
                                       List<BookingLine> lines, PaymentMethod payment, String promoCode,
                                       Runner runner, SalesSummary sales, Instant now) {
        if (payment != PaymentMethod.ABA_KHQR && payment != PaymentMethod.CARD) {
            throw BusinessRuleException.invalid("Choose how to pay.");
        }
        List<BookingLine> wanted = lines == null ? List.of() : List.copyOf(lines);
        Money subtotal = priced(event, wanted, sales, MAX_TICKETS_PER_ONLINE_BOOKING,
                "Maximum " + MAX_TICKETS_PER_ONLINE_BOOKING + " tickets per booking.");
        if (needsRunner && wanted.stream().mapToInt(BookingLine::quantity).sum() > 1) {
            throw BusinessRuleException.invalid("One runner per booking. Book again for another runner.");
        }
        if (needsRunner && runner == null) {
            throw BusinessRuleException.invalid("Add the runner's details.");
        }
        Runner racing = needsRunner ? runner : null;

        Promotion promotion = promotionFor(promoCode, subtotal);
        Money discount = promotion == null ? Money.ZERO : promotion.discountOn(subtotal);

        OnlinePurchase purchase = new OnlinePurchase(buyer.id(), promotion == null ? null : promotion.code(),
                discount, racing);
        return new Booking(id, event.id(), racing == null ? buyer.name() : racing.name(), buyer.phone(), wanted,
                subtotal.minus(discount), payment, SalesChannel.ONLINE, BookingStatus.OPEN,
                racing == null ? List.of() : List.of(racing.shirtSize().code()), null, null, purchase, List.of(),
                null, now);
    }

    /**
     * A purchase of tickets to a place in the Pin app, paid by KHQR or card, of 1 to 8 tickets
     * for one visit day. The price comes from the place's ticket types, less the promo code's
     * discount. Each ticket type has a limit per day: {@code sales} must count only the
     * bookings of that day. The caller makes sure the place is on sale and holds it while the
     * booking is saved. Paying is simulated, as in {@link #boughtOnline}.
     *
     * @param visitDate the day chosen; from {@code today} up to the days a buyer can book ahead
     * @param promoCode as typed; null or blank for none
     * @param sales     the place's sales for {@code visitDate}, for what is left that day
     */
    public static Booking boughtPlaceOnline(BookingId id, Event event, Buyer buyer, List<BookingLine> lines,
                                            PaymentMethod payment, String promoCode, LocalDate visitDate,
                                            LocalDate today, SalesSummary sales, Instant now) {
        if (payment != PaymentMethod.ABA_KHQR && payment != PaymentMethod.CARD) {
            throw BusinessRuleException.invalid("Choose how to pay.");
        }
        event.ensureVisitable(visitDate, today);
        List<BookingLine> wanted = lines == null ? List.of() : List.copyOf(lines);
        Money subtotal = priced(event, wanted, sales, MAX_TICKETS_PER_ONLINE_BOOKING,
                "Maximum " + MAX_TICKETS_PER_ONLINE_BOOKING + " tickets per booking.");
        Promotion promotion = promotionFor(promoCode, subtotal);
        Money discount = promotion == null ? Money.ZERO : promotion.discountOn(subtotal);

        OnlinePurchase purchase = new OnlinePurchase(buyer.id(), promotion == null ? null : promotion.code(),
                discount, null);
        return new Booking(id, event.id(), buyer.name(), buyer.phone(), wanted, subtotal.minus(discount), payment,
                SalesChannel.ONLINE, BookingStatus.OPEN, List.of(), null, null, purchase, List.of(), visitDate, now);
    }

    /**
     * A purchase of seats on a bus trip in the Pin app, paid by KHQR or card, of 1 to 8
     * seats. The price is the seat price times the seats, less the promo code's discount. The
     * seats must be on the coach and free: the caller passes the ones other live bookings
     * hold and holds the event while the booking is saved. Each seat shows the buyer's gender
     * to other buyers. Paying is simulated, as in {@link #boughtOnline}.
     *
     * @param seats       the seat ids chosen, e.g. {@code 3A}
     * @param heldSeats   the seats other live bookings of the trip hold
     * @param promoCode   as typed; null or blank for none
     */
    public static Booking boughtSeatsOnline(BookingId id, Event event, SeatLayout layout, Buyer buyer,
                                            List<String> seats, PaymentMethod payment, String promoCode,
                                            Set<String> heldSeats, SalesSummary sales, Instant now) {
        if (payment != PaymentMethod.ABA_KHQR && payment != PaymentMethod.CARD) {
            throw BusinessRuleException.invalid("Choose how to pay.");
        }
        List<String> chosen = seats == null ? List.of() : List.copyOf(seats);
        if (chosen.isEmpty()) {
            throw BusinessRuleException.invalid("Choose at least one seat.");
        }
        if (chosen.size() > MAX_TICKETS_PER_ONLINE_BOOKING) {
            throw BusinessRuleException.invalid("Choose at most " + MAX_TICKETS_PER_ONLINE_BOOKING
                    + " seats per booking.");
        }
        if (chosen.stream().distinct().count() != chosen.size()) {
            throw BusinessRuleException.invalid("Choose each seat once.");
        }
        for (String seat : chosen) {
            if (!layout.hasSeat(seat)) {
                throw BusinessRuleException.invalid("Seat " + seat + " does not exist "
                        + (layout.isHall() ? "in this hall." : "on this bus."));
            }
        }
        for (String seat : chosen) {
            if (heldSeats.contains(seat)) {
                throw BusinessRuleException.conflict("Seat " + seat + " has just been taken. Choose another seat.");
            }
        }

        List<BookingLine> wanted = List.of(new BookingLine(BusTrip.SEAT_TICKET, chosen.size()));
        Money subtotal = priced(event, wanted, sales, MAX_TICKETS_PER_ONLINE_BOOKING,
                "Choose at most " + MAX_TICKETS_PER_ONLINE_BOOKING + " seats per booking.");
        Promotion promotion = promotionFor(promoCode, subtotal);
        Money discount = promotion == null ? Money.ZERO : promotion.discountOn(subtotal);

        OnlinePurchase purchase = new OnlinePurchase(buyer.id(), promotion == null ? null : promotion.code(),
                discount, null);
        return new Booking(id, event.id(), buyer.name(), buyer.phone(), wanted, subtotal.minus(discount), payment,
                SalesChannel.ONLINE, BookingStatus.OPEN, List.of(), null, null, purchase,
                chosen.stream().map(seat -> new SeatBooking(seat, buyer.gender())).toList(), null, now);
    }

    /**
     * The promo code the buyer typed, checked against the price; null when none was typed.
     * Unknown codes, codes on free tickets and orders below the code's minimum are refused.
     */
    private static Promotion promotionFor(String promoCode, Money subtotal) {
        if (promoCode == null || promoCode.isBlank()) {
            return null;
        }
        Promotion promotion = Promotions.find(promoCode).orElseThrow(() -> BusinessRuleException.invalid(
                promoCode.strip().toUpperCase(Locale.ROOT) + " is not a valid promo code."));
        if (subtotal.cents() == 0) {
            throw BusinessRuleException.invalid(promotion.code() + " can't be used on free tickets.");
        }
        if (!promotion.appliesTo(subtotal)) {
            throw BusinessRuleException.invalid(promotion.code() + " needs an order of "
                    + promotion.minimumSpend().toDisplayString() + " or more.");
        }
        return promotion;
    }

    /**
     * The tickets' price, after checking the lines: at least one ticket, at most
     * {@code most}, each ticket type once, and no more than are left for the event and
     * for each ticket type.
     *
     * @param tooManyMessage what to say when there are more than {@code most}
     */
    private static Money priced(Event event, List<BookingLine> wanted, SalesSummary sales, int most,
                                String tooManyMessage) {
        int count = wanted.stream().mapToInt(BookingLine::quantity).sum();
        if (count == 0) {
            throw BusinessRuleException.invalid("Choose at least one ticket.");
        }
        if (count > most) {
            throw BusinessRuleException.invalid(tooManyMessage);
        }
        if (wanted.stream().map(BookingLine::ticketType).distinct().count() != wanted.size()) {
            throw BusinessRuleException.invalid("List each ticket type once.");
        }
        if (count > sales.left()) {
            throw BusinessRuleException.conflict(sales.left() == 0
                    ? "Sold out. No tickets left to sell."
                    : "Only " + sales.left() + " left.");
        }

        Money total = Money.ZERO;
        for (BookingLine line : wanted) {
            TicketType type = event.ticketType(line.ticketType()).orElseThrow(() ->
                    BusinessRuleException.invalid("This event has no ticket type called " + line.ticketType() + "."));
            int left = sales.leftOf(type.name());
            if (line.quantity() > left) {
                throw BusinessRuleException.conflict(left == 0
                        ? type.name() + " is sold out."
                        : "Only " + left + " left for " + type.name() + ".");
            }
            total = total.plus(type.price().times(line.quantity()));
        }
        return total;
    }

    /**
     * Admits every ticket on the booking, once. A second scan never admits: it
     * answers with the first scan's time and staff name. The caller makes sure the
     * event's check-in is open and that nobody else changes the booking meanwhile.
     */
    public CheckInResult checkIn(StaffMember staff, Instant now) {
        return switch (status) {
            case CANCELLED -> new CheckInResult.Cancelled(this);
            case CHECKED_IN -> new CheckInResult.AlreadyUsed(this);
            case OPEN -> {
                status = BookingStatus.CHECKED_IN;
                checkIn = new CheckIn(now, staff.id(), staff.name());
                yield new CheckInResult.Admitted(this);
            }
        };
    }

    /**
     * A place's tickets are good on their visit day only: before it they are not valid yet,
     * after it they have expired. Any other booking has no visit day and passes.
     */
    public void ensureVisitDay(LocalDate today) {
        if (visitDate == null || visitDate.equals(today)) {
            return;
        }
        String day = visitDate.format(VISIT_DAY);
        if (visitDate.isAfter(today)) {
            throw BusinessRuleException.conflict("This ticket is for " + day + ". Check-in opens on that day.");
        }
        throw BusinessRuleException.conflict("This ticket was for " + day + " and has expired.");
    }

    /** Whether a place's visit day is over, so the booking can no longer be changed. */
    public boolean isVisitOver(LocalDate today) {
        return visitDate != null && visitDate.isBefore(today);
    }

    /**
     * The business calls the booking off, for a reason the buyer is shown. A booking
     * that is checked in cannot be cancelled: its guests are already in. Cancelling a
     * cancelled booking changes nothing, so a request sent again gets the same answer.
     * The caller makes sure the event has not ended and that nobody else changes the
     * booking meanwhile.
     *
     * @return whether it was cancelled now
     */
    public boolean cancel(StaffMember by, CancelReason reason, Instant now) {
        if (reason == null) {
            throw BusinessRuleException.invalid("Choose why the booking is cancelled.");
        }
        return switch (status) {
            case CANCELLED -> false;
            case CHECKED_IN -> throw BusinessRuleException.conflict(
                    "This booking is checked in, so it can't be cancelled.");
            case OPEN -> {
                status = BookingStatus.CANCELLED;
                cancellation = new Cancellation(now, by.id(), by.name(), reason);
                yield true;
            }
        };
    }

    /**
     * What Pin pays back to the buyer: everything they paid, for an online booking the
     * business cancelled. Zero otherwise: a door sale is paid back by the business
     * itself, at the door.
     */
    public Money refund() {
        return cancellation != null && channel == SalesChannel.ONLINE ? total : Money.ZERO;
    }

    /**
     * The business's part of the tickets' full price ({@link #subtotal()}): the price minus
     * Pin's commission at {@code rate} percent. Pin pays for promo codes, so a discount
     * does not make the business's part smaller. When Pin had already paid it out and then
     * refunds the buyer, this is what it takes back.
     */
    public Money businessShare(BigDecimal rate) {
        Money price = subtotal();
        return price.minus(price.percent(rate));
    }

    public boolean isFor(EventId event) {
        return eventId.equals(event);
    }

    /** Cancelled bookings leave the sold, revenue and commission totals. */
    public boolean countsAsSold() {
        return status != BookingStatus.CANCELLED;
    }

    /** This many people walk in together. */
    public int ticketCount() {
        return lines.stream().mapToInt(BookingLine::quantity).sum();
    }

    public int quantityOf(String ticketType) {
        return lines.stream().filter(line -> line.ticketType().equals(ticketType)).mapToInt(BookingLine::quantity).sum();
    }

    /** {@code 2× 10K, 1× 5K Fun run} */
    public String summary() {
        return lines.stream().map(BookingLine::toString).collect(Collectors.joining(", "));
    }

    /**
     * Pin's commission on this booking: {@code rate} percent of the tickets' full price for
     * online sales (Pin pays for promo codes), none on door sales.
     */
    public Money commission(BigDecimal rate) {
        return countsAsSold() && channel == SalesChannel.ONLINE ? subtotal().percent(rate) : Money.ZERO;
    }

    public BookingId id() {
        return id;
    }

    public EventId eventId() {
        return eventId;
    }

    public String buyerName() {
        return buyerName;
    }

    public PhoneNumber phone() {
        return phone;
    }

    public List<BookingLine> lines() {
        return lines;
    }

    /**
     * What the buyer paid, after any promo discount. The business is paid on the full price,
     * {@link #subtotal()}: Pin pays for promo codes.
     */
    public Money total() {
        return total;
    }

    public PaymentMethod payment() {
        return payment;
    }

    public SalesChannel channel() {
        return channel;
    }

    public BookingStatus status() {
        return status;
    }

    /** One per ticket, for running events only. */
    public List<String> tshirtSizes() {
        return tshirtSizes;
    }

    /** Set exactly when the booking is checked in. */
    public CheckIn checkIn() {
        return checkIn;
    }

    /** Set when the business cancelled the booking; null otherwise. */
    public Cancellation cancellation() {
        return cancellation;
    }

    /** Set when it was bought in the Pin app; null for door sales and the demo's sample bookings. */
    public OnlinePurchase purchase() {
        return purchase;
    }

    /** The seats of a bus trip, one per ticket, as they were booked; empty for any other event. */
    public List<SeatBooking> seats() {
        return seats;
    }

    /** The day a place's tickets are good for; null for any other event. */
    public LocalDate visitDate() {
        return visitDate;
    }

    /** What the promo code took off; zero when none was used. */
    public Money discount() {
        return purchase == null ? Money.ZERO : purchase.discount();
    }

    /** The tickets' full price, before any discount: what the business is paid on. */
    public Money subtotal() {
        return total.plus(discount());
    }

    public boolean isBoughtBy(BuyerId buyer) {
        return purchase != null && purchase.buyer().equals(buyer);
    }

    public Instant createdAt() {
        return createdAt;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Booking that && id.equals(that.id);
    }

    @Override
    public int hashCode() {
        return id.hashCode();
    }

    @Override
    public String toString() {
        return "Booking[" + id + ", " + status.code() + "]";
    }
}
