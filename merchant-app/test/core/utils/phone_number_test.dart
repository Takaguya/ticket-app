import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/utils/phone_number.dart';

void main() {
  group('PhoneNumber.national', () {
    test('drops spaces and the leading 0', () {
      expect(PhoneNumber.national('012 345 678'), '12345678');
      expect(PhoneNumber.national('12 345 678'), '12345678');
    });

    test('drops the +855 country code', () {
      expect(PhoneNumber.national('+85512345678'), '12345678');
      expect(PhoneNumber.national('+855 12 345 678'), '12345678');
    });

    test('keeps a national number that happens to start with 855', () {
      // 085 is a real Cambodian prefix, so 85 5xx xxx is not a country code.
      expect(PhoneNumber.national('85 512 345'), '85512345');
    });
  });

  group('PhoneNumber.isValid', () {
    test('accepts 8 and 9 digit numbers', () {
      expect(PhoneNumber.isValid('12 345 678'), isTrue);
      expect(PhoneNumber.isValid('097 123 4567'), isTrue);
    });

    test('rejects numbers that are too short, too long or empty', () {
      expect(PhoneNumber.isValid('12 345 67'), isFalse);
      expect(PhoneNumber.isValid('12 345 678 90'), isFalse);
      expect(PhoneNumber.isValid(''), isFalse);
    });
  });

  test('toE164 gives the form sent to the API', () {
    expect(PhoneNumber.toE164('012 345 678'), '+85512345678');
  });

  test('display groups the digits for reading', () {
    expect(PhoneNumber.display('+85512345678'), '+855 12 345 678');
    expect(PhoneNumber.display('0971234567'), '+855 97 123 4567');
  });
}
