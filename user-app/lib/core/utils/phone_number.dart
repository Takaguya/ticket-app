/// Cambodian phone number helpers. The app only accepts +855 numbers.
abstract final class PhoneNumber {
  static const countryCode = '+855';

  /// The national digits without the leading 0 or country code:
  /// `012 345 678` and `+85512345678` both give `12345678`.
  static String national(String input) {
    final trimmed = input.trim();
    final withoutCountry = trimmed.startsWith(countryCode)
        ? trimmed.substring(countryCode.length)
        : trimmed;
    final digits = withoutCountry.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('0') ? digits.substring(1) : digits;
  }

  /// Cambodian numbers have 8 or 9 digits after the leading 0.
  static bool isValid(String input) {
    final length = national(input).length;
    return length >= 8 && length <= 9;
  }

  /// `+85512345678`, the form sent to the API.
  static String toE164(String input) => '$countryCode${national(input)}';

  /// `12 345 678`
  static String formatNational(String input) {
    final digits = national(input);
    if (digits.length <= 2) return digits;
    if (digits.length <= 5) return '${digits.substring(0, 2)} ${digits.substring(2)}';
    return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
  }

  /// `+855 12 345 678`
  static String display(String input) => '$countryCode ${formatNational(input)}';

  /// `012 345 678`, as people write numbers in Cambodia.
  static String local(String input) => '0${formatNational(input)}';
}
