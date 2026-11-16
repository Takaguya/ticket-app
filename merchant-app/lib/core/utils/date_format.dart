/// Date and time text in the style the app uses (24-hour clock, English
/// month names).
abstract final class DateFormat {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  /// `Nov`
  static String month(DateTime date) => _months[date.month - 1];

  /// `05:30`
  static String time(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// `8 Nov`
  static String dayMonth(DateTime date) => '${date.day} ${month(date)}';

  /// `8 Nov 2026`
  static String full(DateTime date) => '${dayMonth(date)} ${date.year}';
}

/// `1 ticket`, `3 tickets`
String ticketsLabel(int count) => count == 1 ? '1 ticket' : '$count tickets';
