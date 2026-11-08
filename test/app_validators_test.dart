import 'package:flutter_test/flutter_test.dart';
import 'package:deliv_track/utils/app_validators.dart';

void main() {
  group('AppValidators tests', () {
    test('required validator', () {
      expect(
        AppValidators.required(null, fieldName: 'Customer Name'),
        'Customer Name is required',
      );
      expect(
        AppValidators.required('', fieldName: 'Customer Name'),
        'Customer Name is required',
      );
      expect(
        AppValidators.required('   ', fieldName: 'Customer Name'),
        'Customer Name is required',
      );
      expect(
        AppValidators.required('Saleem Tailor', fieldName: 'Customer Name'),
        isNull,
      );
    });

    test('email validator', () {
      expect(
        AppValidators.email(null, isRequired: true),
        'Email address is required',
      );
      expect(
        AppValidators.email('', isRequired: true),
        'Email address is required',
      );
      expect(AppValidators.email(null, isRequired: false), isNull);
      expect(
        AppValidators.email('invalid', isRequired: true),
        'Enter a valid email address',
      );
      expect(
        AppValidators.email('test@domain', isRequired: true),
        'Enter a valid email address',
      );
      expect(
        AppValidators.email('saleem@codewingz.com', isRequired: true),
        isNull,
      );
    });

    test('password validator', () {
      expect(
        AppValidators.password(null, isRequired: true),
        'Password is required',
      );
      expect(
        AppValidators.password('12345', isRequired: true),
        'Password must be at least 6 characters',
      );
      expect(AppValidators.password('123456', isRequired: true), isNull);
    });

    test(
      'new password rule (sign-up): 8+ characters with a letter and a number',
      () {
        expect(AppValidators.newPassword(null), 'Password is required');
        expect(
          AppValidators.newPassword('abc123'),
          'Password must be at least 8 characters',
        );
        expect(
          AppValidators.newPassword('1234567'),
          'Password must be at least 8 characters',
        );
        expect(
          AppValidators.newPassword('12345678'),
          'Use a mix of letters and numbers',
        );
        expect(
          AppValidators.newPassword('abcdefgh'),
          'Use a mix of letters and numbers',
        );
        expect(AppValidators.newPassword('abcd1234'), isNull);
        expect(AppValidators.newPassword('Secret #1 phrase'), isNull);
      },
    );

    test('logging in still accepts an existing 6-character password', () {
      expect(AppValidators.password('abc123', isRequired: true), isNull);
    });

    test('amount validator', () {
      expect(
        AppValidators.amount(null, isRequired: true),
        'Amount is required',
      );
      expect(
        AppValidators.amount('abc', isRequired: true),
        'Enter a valid amount',
      );
      expect(
        AppValidators.amount('50', minPaisa: 10000),
        'Minimum amount is Rs. 100',
      );
      expect(
        AppValidators.amount('150', maxPaisa: 10000),
        'Maximum amount is Rs. 100',
      );
      expect(AppValidators.amount('1200.50'), isNull);
    });

    test('weight validator', () {
      expect(
        AppValidators.weight(null, isRequired: true),
        'Weight is required',
      );
      expect(
        AppValidators.weight('0', isRequired: true),
        'Enter a valid weight in kg',
      );
      expect(
        AppValidators.weight('-1', isRequired: true),
        'Enter a valid weight in kg',
      );
      expect(AppValidators.weight('2.5', isRequired: true), isNull);
    });

    test('phone validator', () {
      expect(
        AppValidators.phone(null, isRequired: true),
        'Phone number is required',
      );
      expect(AppValidators.phone('12345'), 'Enter a valid phone number');
      expect(AppValidators.phone('03001234567'), isNull);
      expect(AppValidators.phone('+92 300 1234567'), isNull);
    });
  });
}
