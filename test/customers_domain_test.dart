import 'package:deliv_track/utils/app_validators.dart';
import 'package:deliv_track/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('Pakistan numbers in any written form become 0…', () {
      for (final raw in ['03001234567', '0300 1234567', '0300-1234567', '+92 300 1234567', '+923001234567', '923001234567', '00923001234567']) {
        expect(normalizePhone(raw), '03001234567', reason: raw);
      }
    });

    test('other numbers keep their digits only', () {
      expect(normalizePhone('+44 20 7946 0958'), '442079460958');
      expect(normalizePhone('042 3576-1234'), '04235761234');
      expect(normalizePhone(''), '');
    });
  });

  group('phone validation', () {
    const valid = [
      '03001234567', '0300 1234567', '0300-1234567', '+92 300 1234567', '+923001234567', '923001234567',
      '00923001234567', '0411234567', '042 35761234', '+44 20 7946 0958', '1234567890', '123456789012345',
    ];
    const invalid = [
      '', '   ', '12345', '123456789', '0300123456', '030012345678', 'abcdefghijk', '0300abc4567',
      '++923001234567', '0300+1234567', '(0300) 1234567', '1234567890123456', '0300 123 45 67 89 0123',
    ];

    test('accepts real-world formats', () {
      for (final raw in valid) {
        expect(isValidPhone(raw), isTrue, reason: raw);
      }
    });

    test('rejects malformed numbers (mobiles must have exactly 11 digits)', () {
      for (final raw in invalid) {
        expect(isValidPhone(raw), isFalse, reason: raw);
      }
    });

    test('AppValidators.phone messages', () {
      expect(AppValidators.phone(null), 'Phone number is required');
      expect(AppValidators.phone('   '), 'Phone number is required');
      expect(AppValidators.phone('12345'), 'Enter a valid phone number');
      expect(AppValidators.phone('0300 1234567'), isNull);
      expect(AppValidators.phone('', isRequired: false), isNull);
    });
  });

  group('AppValidators.address', () {
    test('required and 5-200 characters after trimming', () {
      expect(AppValidators.address(null, fieldName: 'Full address'), 'Full address is required');
      expect(AppValidators.address('    '), 'Address is required');
      expect(AppValidators.address(' abcd '), 'Enter the full address (5–200 characters)');
      expect(AppValidators.address('abcde'), isNull);
      expect(AppValidators.address('x' * 200), isNull);
      expect(AppValidators.address('x' * 201), 'Enter the full address (5–200 characters)');
    });
  });
}
