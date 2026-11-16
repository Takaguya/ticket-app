import '../../../../core/utils/date_format.dart';
import '../../../events/domain/entities/event.dart';
import 'booking.dart';
import 'booking_filter.dart';
import 'sales_summary.dart';

/// A CSV file ready to be saved or shared.
class CsvFile {
  const CsvFile({required this.name, required this.content});

  /// e.g. `phnom-penh-half-marathon-2026-bookings.csv`
  final String name;
  final String content;
}

/// Builds the owner's bookings export for one event.
abstract final class BookingsCsv {
  static const _columns = [
    'Booking ID',
    'Name',
    'Phone',
    'Tickets',
    'Category',
    'T-shirt sizes',
    'Total (USD)',
    'Pin commission (USD)',
    'You receive (USD)',
    'Payment',
    'Sold',
    'Status',
    'Checked in at',
    'Checked in by',
    'Runner',
    'Runner phone',
    'Runner email',
    'Runner gender',
    'Runner age',
    'Runner nationality',
    'Emergency contact',
    'Emergency phone',
    'Visit date',
  ];

  static CsvFile build({
    required Event event,
    required List<Booking> bookings,
    BookingFilter filter = BookingFilter.all,
  }) {
    final rows = [
      _columns,
      for (final booking in bookings) _row(booking, event.commissionRate),
    ];
    // The byte order mark makes Excel read the file as UTF-8.
    final content = '﻿${rows.map((row) => row.map(_escape).join(',')).join('\r\n')}';

    final suffix = filter == BookingFilter.all ? '' : '-${_slug(filter.label)}';
    return CsvFile(name: '${_slug(event.name)}-bookings$suffix.csv', content: content);
  }

  static List<String> _row(Booking booking, double commissionRate) {
    final commission = SalesSummary.commissionOf(booking, commissionRate);
    final received = booking.countsAsSold ? booking.totalCents - commission : 0;
    final checkIn = booking.checkIn;
    final runner = booking.runner;
    return [
      booking.id,
      booking.buyerName,
      booking.phone,
      '${booking.ticketCount}',
      booking.summary,
      booking.tshirtSizes.join(' '),
      _amount(booking.totalCents),
      _amount(commission),
      _amount(received),
      booking.payment.label,
      booking.channel.label,
      booking.status.label,
      if (checkIn == null) '' else '${DateFormat.full(checkIn.at)} ${DateFormat.time(checkIn.at)}',
      checkIn?.staffName ?? '',
      runner?.name ?? '',
      runner?.phone ?? '',
      runner?.email ?? '',
      runner?.gender ?? '',
      if (runner == null) '' else '${runner.age}',
      runner?.nationality ?? '',
      runner?.emergencyName ?? '',
      runner?.emergencyPhone ?? '',
      // The day a place's tickets are for, e.g. 2026-11-28; empty for any other event.
      if (booking.visitDate == null) '' else _isoDay(booking.visitDate!),
    ];
  }

  static String _isoDay(DateTime day) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
  }

  /// `12.50`, without a currency sign so spreadsheets treat it as a number.
  static String _amount(int cents) => (cents / 100).toStringAsFixed(2);

  static String _escape(String value) => '"${value.replaceAll('"', '""')}"';

  static String _slug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
