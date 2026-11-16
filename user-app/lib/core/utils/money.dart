/// Money helpers. Amounts are whole US cents (`1250` is $12.50) so sums never
/// pick up floating-point error.
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

  /// `Free` for nothing, otherwise as [format].
  static String formatPrice(int cents) => cents == 0 ? 'Free' : format(cents);
}
