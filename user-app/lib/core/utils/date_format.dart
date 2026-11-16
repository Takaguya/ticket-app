/// Date and time text in the style the app uses (24-hour clock, English
/// month and day names).
abstract final class DateFormat {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// `Nov`
  static String month(DateTime date) => _months[date.month - 1];

  /// `Sun`
  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  /// `05:30`
  static String time(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// `22 Nov`
  static String dayMonth(DateTime date) => '${date.day} ${month(date)}';

  /// `22 Nov 2026`
  static String full(DateTime date) => '${dayMonth(date)} ${date.year}';

  /// `Sun 22 Nov 2026`
  static String long(DateTime date) => '${weekday(date)} ${full(date)}';

  /// `Today, 15 Nov`, `Tomorrow, 16 Nov` or `Tue, 17 Nov`.
  static String relativeDay(DateTime date, {required DateTime today}) {
    final days = dateOnly(date).difference(dateOnly(today)).inDays;
    final name = switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => weekday(date),
    };
    return '$name, ${dayMonth(date)}';
  }

  /// `6h`, `5h 30m` or `45m`.
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  /// Midnight at the start of [date]'s day.
  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}
