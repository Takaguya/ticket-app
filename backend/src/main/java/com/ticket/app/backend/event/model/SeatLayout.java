package com.ticket.app.backend.event.model;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import com.ticket.app.backend.shared.model.BusinessRuleException;

/**
 * The seats of a coach or a cinema hall.
 *
 * <p>A coach is chosen by type: a standard seater has 10 rows of 2+2, a VIP seater 10 rows
 * of 2+1 and a sleeper 8 rows of 1+1 beds. Its seats are named by row number and column,
 * e.g. {@code 3A}. A hall is chosen by size: small has 6 rows of 8 seats, standard 8 rows of
 * 10 and large 10 rows of 12, in blocks with aisles between. Its seats are named by row
 * letter and number, e.g. {@code F5}. Front row first; the same shapes as the user app's
 * seat maps.
 */
public enum SeatLayout {
    SEATER("seater", "Seater · 2+2", false, 10, new String[] {"A", "B", null, "C", "D"}),
    VIP("vip", "VIP seater · 2+1", false, 10, new String[] {"A", null, "B", "C"}),
    SLEEPER("sleeper", "Sleeper · 1+1", false, 8, new String[] {"A", null, "B"}),
    HALL_SMALL("small", "Small hall · 48 seats", true, 6,
            new String[] {"1", "2", null, "3", "4", "5", "6", null, "7", "8"}),
    HALL_STANDARD("standard", "Standard hall · 80 seats", true, 8,
            new String[] {"1", "2", "3", null, "4", "5", "6", "7", null, "8", "9", "10"}),
    HALL_LARGE("large", "Large hall · 120 seats", true, 10,
            new String[] {"1", "2", "3", null, "4", "5", "6", "7", "8", "9", null, "10", "11", "12"});

    /**
     * One seat on the map. {@code label} is what the seat shows (a coach seat's own name, a hall
     * seat's number); {@code detail} says where it is.
     */
    public record Spot(String id, String label, String detail) {
    }

    private final String code;
    private final String label;
    private final boolean hall;
    private final int rowCount;
    /** The columns left to right; null is the aisle. */
    private final String[] columns;

    SeatLayout(String code, String label, boolean hall, int rowCount, String[] columns) {
        this.code = code;
        this.label = label;
        this.hall = hall;
        this.rowCount = rowCount;
        this.columns = columns;
    }

    /** The stable name used in the API and the database. */
    public String code() {
        return code;
    }

    /** e.g. {@code Seater · 2+2}, shown to buyers. */
    public String label() {
        return label;
    }

    /** A cinema hall, as opposed to a coach. */
    public boolean isHall() {
        return hall;
    }

    /** The map, front row first. A null in a row is the aisle. */
    public List<List<Spot>> rows() {
        List<List<Spot>> rows = new ArrayList<>();
        for (int row = 1; row <= rowCount; row++) {
            List<Spot> spots = new ArrayList<>();
            for (int index = 0; index < columns.length; index++) {
                String column = columns[index];
                if (column == null) {
                    spots.add(null);
                } else if (hall) {
                    String letter = String.valueOf((char) ('A' + row - 1));
                    spots.add(new Spot(letter + column, column, "Row " + letter));
                } else {
                    boolean window = index == 0 || index == columns.length - 1;
                    String id = row + column;
                    spots.add(new Spot(id, id, "Row " + row + " · " + (window ? "Window" : "Aisle")));
                }
            }
            rows.add(spots);
        }
        return rows;
    }

    /** Every seat, front row first, left to right. */
    public List<String> seatIds() {
        return rows().stream().flatMap(List::stream).filter(spot -> spot != null).map(Spot::id).toList();
    }

    public int capacity() {
        return rowCount * (int) Arrays.stream(columns).filter(column -> column != null).count();
    }

    public boolean hasSeat(String id) {
        return seatIds().contains(id);
    }

    /** The coach with this code. */
    public static SeatLayout coachFromCode(String code) {
        return find(code).filter(layout -> !layout.hall)
                .orElseThrow(() -> BusinessRuleException.invalid("Choose the kind of coach."));
    }

    /** The hall with this size code: small, standard or large. */
    public static SeatLayout hallFromCode(String code) {
        return find(code).filter(layout -> layout.hall)
                .orElseThrow(() -> BusinessRuleException.invalid("Choose the size of the hall."));
    }

    /** The layout with this code, if there is one. */
    public static Optional<SeatLayout> find(String code) {
        return Arrays.stream(values()).filter(layout -> layout.code.equals(code)).findFirst();
    }
}
