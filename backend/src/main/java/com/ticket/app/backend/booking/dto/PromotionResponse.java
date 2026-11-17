package com.ticket.app.backend.booking.dto;

import com.ticket.app.backend.booking.model.Promotion;

/** A promo code a buyer can use, matching the user app's Promotion. Money is whole US cents. */
public record PromotionResponse(String code, String title, String description, int percentOff, long amountOffCents,
                         long minimumSpendCents) {

    public static PromotionResponse of(Promotion promotion) {
        return new PromotionResponse(promotion.code(), promotion.title(), promotion.description(),
                promotion.percentOff(), promotion.amountOff().cents(), promotion.minimumSpend().cents());
    }
}
