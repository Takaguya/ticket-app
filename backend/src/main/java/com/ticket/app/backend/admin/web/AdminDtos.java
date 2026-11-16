package com.ticket.app.backend.admin.web;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.ticket.app.backend.admin.application.BackOfficeService;
import com.ticket.app.backend.admin.domain.BookingOverview;
import com.ticket.app.backend.admin.domain.EventOverview;
import com.ticket.app.backend.admin.domain.MerchantOverview;
import com.ticket.app.backend.business.domain.Business;
import com.ticket.app.backend.event.domain.Event;
import com.ticket.app.backend.event.domain.EventImage;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * JSON of the admin panel's endpoints. Money is whole US cents; enum values use the
 * apps' names ({@code pending}, {@code awaitingApproval}, {@code abaKhqr}...). Times are
 * local to Pin's time zone, without an offset.
 */
final class AdminDtos {

    private AdminDtos() {
    }

    /** {@code period}: the days figures are counted for; {@code today}: today in Pin's time zone. */
    record OverviewResponse(PeriodResponse period, LocalDate today, double commissionRate) {
    }

    record PeriodResponse(LocalDate from, LocalDate to) {

        static PeriodResponse of(BackOfficeService.Period period) {
            return new PeriodResponse(period.from(), period.to());
        }
    }

    /** {@code owner} is null only if the owner's record is missing. */
    record MerchantResponse(String id, String name, String type, String status, OwnerResponse owner, int events,
                            long onlineSalesCents, long commissionCents, LocalDateTime registeredAt) {

        static MerchantResponse of(MerchantOverview merchant, ZoneId zone) {
            return new MerchantResponse(merchant.id().toString(), merchant.name(), merchant.type().code(),
                    merchant.status().code(),
                    merchant.ownerIfKnown().map(o -> new OwnerResponse(o.name(), o.phone().value())).orElse(null),
                    merchant.events(), merchant.onlineSales().cents(), merchant.commission().cents(),
                    LocalDateTime.ofInstant(merchant.registeredAt(), zone).truncatedTo(ChronoUnit.SECONDS));
        }
    }

    record OwnerResponse(String name, String phone) {
    }

    /** The business after an admin changed its status. */
    record MerchantStatusResponse(String id, String name, String status) {

        static MerchantStatusResponse of(Business business) {
            return new MerchantStatusResponse(business.id().toString(), business.name(), business.status().code());
        }
    }

    /**
     * {@code status}: awaitingApproval, live, onSale, paused (its business is suspended) or ended.
     * {@code kind}: marathon, concert, show, bus, cinema or admission. A place (admission) is open
     * every day: its {@code startsAt} is only the day it was published, its {@code sold} counts every
     * day's tickets and its {@code capacity} is 0, because its limits are per day. {@code imageUrl} is the
     * event's cover image on this server, or null when it has none.
     */
    record EventResponse(String id, String name, String venue, LocalDateTime startsAt, String merchantId,
                         String merchantName, String status, int sold, int capacity, String kind, String imageUrl) {

        static EventResponse of(EventOverview event, LocalDate today) {
            return new EventResponse(event.id().toString(), event.name(), event.venue(), event.startsAt(),
                    event.merchantId().toString(), event.merchantName(), event.statusOn(today).code(), event.sold(),
                    event.kind().isOpenEveryDay() ? 0 : event.capacity(), event.kind().code(),
                    EventImage.urlOf(event.id(), event.imageVersion()));
        }
    }

    /** An event's image after an admin set it: where it is now. */
    record ImageResponse(String imageUrl) {

        static ImageResponse of(EventImage image) {
            return new ImageResponse(EventImage.urlOf(image.eventId(), image.version()));
        }
    }

    /** The event after an admin approved it. */
    record ApprovedEventResponse(String id, String name, boolean approved) {

        static ApprovedEventResponse of(Event event) {
            return new ApprovedEventResponse(event.id().toString(), event.name(), event.isApproved());
        }
    }

    /** {@code total}: how many bookings match in all; {@code bookings} holds the newest of them. */
    record BookingsResponse(int total, int page, int size, int pages, List<BookingResponse> bookings) {

        static BookingsResponse of(BookingOverview.Page page, ZoneId zone) {
            return new BookingsResponse(page.total(), page.number(), page.size(), page.pages(),
                    page.bookings().stream().map(booking -> BookingResponse.of(booking, zone)).toList());
        }
    }

    record BookingResponse(String id, String buyerName, String eventName, String merchantName, int tickets,
                           long totalCents, String payment, String channel, String status, LocalDateTime createdAt) {

        static BookingResponse of(BookingOverview booking, ZoneId zone) {
            return new BookingResponse(booking.id().value(), booking.buyerName(), booking.eventName(),
                    booking.merchantName(), booking.tickets(), booking.total().cents(), booking.payment().code(),
                    booking.channel().code(), booking.status().code(),
                    LocalDateTime.ofInstant(booking.createdAt(), zone).truncatedTo(ChronoUnit.SECONDS));
        }
    }

    /** {@code owed}: what Pin owes now, largest first. {@code paid}: payouts this period, newest first. */
    record PayoutsResponse(List<OwedResponse> owed, List<PaidResponse> paid) {

        static PayoutsResponse of(BackOfficeService.Payouts payouts, ZoneId zone) {
            return new PayoutsResponse(
                    payouts.owed().stream().map(OwedResponse::of).toList(),
                    payouts.paid().stream().map(paid -> PaidResponse.of(paid, zone)).toList());
        }
    }

    /**
     * {@code refundsCents}: the merchant's share of paid-out bookings it cancelled since,
     * which Pin refunded to the buyers and takes back from this payout.
     */
    record OwedResponse(String merchantId, String merchantName, long grossCents, long commissionCents,
                        long refundsCents, long netCents, int bookingCount) {

        static OwedResponse of(BackOfficeService.Owed owed) {
            var due = owed.due();
            return new OwedResponse(due.businessId().toString(), owed.businessName(), due.gross().cents(),
                    due.commission().cents(), due.refunds().cents(), due.net().cents(), due.bookings().size());
        }
    }

    record PaidResponse(String id, String merchantId, String merchantName, long grossCents, long commissionCents,
                        long refundsCents, long netCents, int bookingCount, LocalDateTime paidAt, String paidBy) {

        static PaidResponse of(BackOfficeService.Paid paid, ZoneId zone) {
            var payout = paid.payout();
            return new PaidResponse(payout.id().toString(), payout.businessId().toString(), paid.businessName(),
                    payout.gross().cents(), payout.commission().cents(), payout.refunds().cents(),
                    payout.net().cents(), payout.bookingCount(),
                    LocalDateTime.ofInstant(payout.paidAt(), zone).truncatedTo(ChronoUnit.SECONDS),
                    payout.paidBy().name());
        }
    }

    /**
     * {@code netCents}: the amount the admin saw and sent. Refused (409) if what is owed
     * changed since, so the record always matches the money that went out.
     */
    record PayRequest(
            @NotBlank(message = "Choose the business to pay.") String merchantId,
            @NotNull(message = "Enter the amount paid.") @PositiveOrZero(message = "Enter the amount paid.")
            Long netCents) {
    }
}
