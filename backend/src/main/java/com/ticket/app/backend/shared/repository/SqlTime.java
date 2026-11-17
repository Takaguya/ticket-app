package com.ticket.app.backend.shared.repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * Instants to and from {@code timestamptz} columns. The PostgreSQL driver reads and
 * writes {@link OffsetDateTime}, not {@link Instant}.
 */
public final class SqlTime {

    private SqlTime() {
    }

    public static OffsetDateTime toSql(Instant instant) {
        return instant == null ? null : instant.atOffset(ZoneOffset.UTC);
    }

    /** The column's value, or null when it is null. */
    public static Instant instant(ResultSet rs, String column) throws SQLException {
        OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
        return value == null ? null : value.toInstant();
    }
}
