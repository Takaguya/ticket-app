import 'booking.dart';

/// The status filters above the bookings list.
enum BookingFilter {
  all('All', null),
  open('Not checked in', BookingStatus.open),
  checkedIn('Checked in', BookingStatus.checkedIn),
  cancelled('Cancelled', BookingStatus.cancelled);

  const BookingFilter(this.label, this.status);

  final String label;

  /// The status this filter keeps, or null to keep everything.
  final BookingStatus? status;

  bool accepts(Booking booking) => status == null || booking.status == status;
}

/// Searching the bookings list.
abstract final class BookingSearch {
  /// Whether [booking] matches what was typed: part of the buyer's name,
  /// part of the booking ID, or at least 3 digits of the phone number
  /// (spaces and punctuation in either are ignored).
  static bool matches(Booking booking, String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    if (booking.buyerName.toLowerCase().contains(text)) return true;
    if (booking.id.toLowerCase().contains(text)) return true;

    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 3 && booking.phone.replaceAll(RegExp(r'\D'), '').contains(digits);
  }

  /// The bookings matching [query], sorted by buyer name.
  static List<Booking> search(Iterable<Booking> bookings, String query) {
    return bookings.where((b) => matches(b, query)).toList()
      ..sort((a, b) => a.buyerName.compareTo(b.buyerName));
  }
}
