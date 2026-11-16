/// Money helpers. Amounts are whole US cents (`1250` is $12.50) so sums and
/// commission never pick up floating-point error.
abstract final class Money {
  /// `$1,234.50`
  static String format(int cents) {
    final negative = cents < 0;
    final absolute = cents.abs();
    final dollars = (absolute ~/ 100).toString();
    final grouped = dollars.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '−' : ''}\$$grouped.$fraction';
  }

  /// Parses what a person typed, e.g. `12`, `12.5` or `12.50`. Returns null
  /// when it is not an amount.
  static int? parse(String input) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
    if (match == null) return null;
    final dollars = int.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return dollars * 100 + int.parse(fraction);
  }

  /// [rate] percent of [cents], rounded to the nearest cent.
  static int percentOf(int cents, double rate) => (cents * rate / 100).round();
}
