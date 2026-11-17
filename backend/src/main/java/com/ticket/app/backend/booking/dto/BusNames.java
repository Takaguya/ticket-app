package com.ticket.app.backend.booking.dto;

import java.util.Locale;

/** How the bus endpoints name routes and bus companies: a route's id and a company's badge. */
public final class BusNames {

    /** The badge colours of bus companies, as 0xAARRGGBB; a company always gets the same one. */
    private static final long[] COLOURS = {0xFF1E8A72L, 0xFF0151A6L, 0xFFD9822BL, 0xFF8E44ADL, 0xFFC0392BL};

    private BusNames() {
    }

    /** {@code phnom-penh-siem-reap}: lower case words joined by dashes. */
    public static String routeId(String origin, String destination) {
        return slug(origin) + "-" + slug(destination);
    }

    private static String slug(String place) {
        // Letters, marks and digits of any script: a Khmer place name must not collapse to nothing.
        return place.strip().toLowerCase(Locale.ROOT).replaceAll("[^\\p{L}\\p{M}\\p{N}]+", "-")
                .replaceAll("^-|-$", "");
    }

    /** Two letters for the company's badge: the first letters of its first two words, else its first two letters. */
    public static String operatorCode(String company) {
        String[] words = company.strip().split("\\s+");
        String code = words.length >= 2 && !words[1].isEmpty()
                ? words[0].substring(0, 1) + words[1].substring(0, 1)
                : company.strip().substring(0, Math.min(2, company.strip().length()));
        return code.isEmpty() ? "BS" : code.toUpperCase(Locale.ROOT);
    }

    public static long operatorColor(String company) {
        return COLOURS[Math.floorMod(company.strip().toLowerCase(Locale.ROOT).hashCode(), COLOURS.length)];
    }
}
