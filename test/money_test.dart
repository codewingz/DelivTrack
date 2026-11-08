import 'package:deliv_track/core/ids/order_number.dart';
import 'package:deliv_track/core/money/money.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/utils/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRupeesToPaisa', () {
    const cases = {
      '0': 0,
      '5': 500,
      '2500': 250000,
      '2,500': 250000,
      '1,234,567': 123456700,
      '2500.5': 250050,
      '2500.50': 250050,
      '0.05': 5,
      '.5': 50,
      '.05': 5,
      '5.': 500,
      '  12 ': 1200,
      '99,999,999': maxMoneyPaisa,
      '99999999.00': maxMoneyPaisa,
    };
    cases.forEach(
      (text, paisa) => test(
        '"$text" -> $paisa',
        () => expect(parseRupeesToPaisa(text), paisa),
      ),
    );

    for (final bad in [
      '',
      ' ',
      '.',
      'abc',
      '-5',
      '+5',
      '1.234',
      '1..2',
      '1.2.3',
      '1,2',
      '12,34',
      '1,2345',
      ',500',
      '5,',
      '1e3',
      'Rs. 5',
      '100000000',
      '99999999.01',
    ]) {
      test('"$bad" is rejected', () => expect(parseRupeesToPaisa(bad), isNull));
    }
  });

  group('formatRupees', () {
    const cases = {
      0: 'Rs. 0',
      5: 'Rs. 0.05',
      50: 'Rs. 0.50',
      100: 'Rs. 1',
      250000: 'Rs. 2,500',
      250050: 'Rs. 2,500.50',
      123456700: 'Rs. 1,234,567',
      99999900: 'Rs. 999,999',
      100000000: 'Rs. 1,000,000',
      -50000: '-Rs. 500',
      -5: '-Rs. 0.05',
    };
    cases.forEach(
      (paisa, text) =>
          test('$paisa -> $text', () => expect(formatRupees(paisa), text)),
    );

    test('parse and format round-trip for many values', () {
      for (final paisa in [
        0,
        1,
        99,
        100,
        101,
        99999,
        100000,
        123456,
        999999999,
        maxMoneyPaisa,
      ]) {
        expect(
          parseRupeesToPaisa(formatRupees(paisa).replaceFirst('Rs. ', '')),
          paisa,
          reason: '$paisa',
        );
      }
    });
  });

  group('kg and grams', () {
    const parse = {
      '1': 1000,
      '1.25': 1250,
      '0.5': 500,
      '.5': 500,
      '0.001': 1,
      '5.': 5000,
      '9999.999': maxWeightGrams,
      '9,999': null,
    };
    parse.forEach(
      (text, grams) =>
          test('"$text" -> $grams', () => expect(parseKgToGrams(text), grams)),
    );

    for (final bad in [
      '',
      '.',
      'abc',
      '-1',
      '1.2345',
      '1..2',
      '10000',
      '9999.9991',
    ]) {
      test('"$bad" is rejected', () => expect(parseKgToGrams(bad), isNull));
    }

    test('formatKg', () {
      expect(formatKg(1250), '1.25 kg');
      expect(formatKg(2000), '2 kg');
      expect(formatKg(5), '0.005 kg');
      expect(formatKg(1500), '1.5 kg');
      expect(formatKg(maxWeightGrams), '9999.999 kg');
    });
  });

  group('line totals', () {
    test('per piece is exact', () {
      expect(pieceLineTotalPaisa(quantity: 3, unitPricePaisa: 250050), 750150);
      expect(
        pieceLineTotalPaisa(quantity: 99999, unitPricePaisa: maxMoneyPaisa),
        99999 * maxMoneyPaisa,
      );
    });

    test('per kg rounds half up to a whole paisa', () {
      expect(weightLineTotalPaisa(grams: 1000, pricePerKgPaisa: 25000), 25000);
      expect(
        weightLineTotalPaisa(grams: 250, pricePerKgPaisa: 10000),
        2500,
      ); // 0.25 kg at Rs. 100
      expect(
        weightLineTotalPaisa(grams: 333, pricePerKgPaisa: 10010),
        3333,
      ); // 3333.33 -> 3333
      expect(
        weightLineTotalPaisa(grams: 1, pricePerKgPaisa: 500),
        1,
      ); // 0.5 paisa -> 1
      expect(
        weightLineTotalPaisa(grams: 1, pricePerKgPaisa: 499),
        0,
      ); // 0.499 -> 0
      expect(weightLineTotalPaisa(grams: 0, pricePerKgPaisa: 99999), 0);
    });

    test('largest values do not overflow', () {
      expect(
        weightLineTotalPaisa(
          grams: maxWeightGrams,
          pricePerKgPaisa: maxMoneyPaisa,
        ),
        isPositive,
      );
    });
  });

  group('AppValidators.amount / weight (paisa/gram based)', () {
    test('amount', () {
      expect(
        AppValidators.amount(null, fieldName: 'Delivery charge'),
        'Delivery charge is required',
      );
      expect(AppValidators.amount('abc'), 'Enter a valid amount');
      expect(AppValidators.amount('1.234'), 'Enter a valid amount');
      expect(AppValidators.amount('0'), isNull);
      expect(
        AppValidators.amount('0', minPaisa: 1),
        'Enter an amount above zero',
      );
      expect(AppValidators.amount('2,500.50'), isNull);
      expect(AppValidators.amount('100000000'), 'Enter a valid amount');
      expect(
        AppValidators.amount('50', maxPaisa: 4000),
        'Maximum amount is Rs. 40',
      );
    });

    test('weight', () {
      expect(AppValidators.weight('0.001', isRequired: true), isNull);
      expect(
        AppValidators.weight('0', isRequired: true),
        'Enter a valid weight in kg',
      );
      expect(
        AppValidators.weight('1.2345', isRequired: true),
        'Enter a valid weight in kg',
      );
      expect(
        AppValidators.weight('10000', isRequired: true),
        'Enter a valid weight in kg',
      );
      expect(AppValidators.weight('', isRequired: false), isNull);
    });
  });

  group('Pakistan time', () {
    test('date is UTC+5 and rolls over at 19:00 UTC', () {
      expect(pakistanDate(DateTime.utc(2026, 11, 7, 18, 59, 59)), '2026-11-07');
      expect(pakistanDate(DateTime.utc(2026, 11, 7, 19, 0, 0)), '2026-11-08');
      expect(pakistanDate(DateTime.utc(2026, 12, 31, 19, 0)), '2027-01-01');
      expect(pakistanDate(DateTime.utc(2028, 2, 28, 20, 0)), '2028-02-29');
      expect(pakistanDate(DateTime.utc(2026, 1, 1, 0, 0)), '2026-01-01');
    });

    test('a non-UTC DateTime is converted first', () {
      expect(
        pakistanDate(DateTime.parse('2026-11-07T23:30:00+05:00')),
        '2026-11-07',
      );
    });

    test('formatDate', () {
      expect(formatDate('2026-11-07'), '7 Nov 2026');
      expect(formatDate('2026-01-31'), '31 Jan 2026');
      expect(formatDate('not a date'), 'not a date');
      expect(formatDate('2026-13-01'), '2026-13-01');
    });
  });

  group('order numbers', () {
    test('zero-padded to 6 digits, growing past it', () {
      expect(formatOrderNumber(1), 'ADT-000001');
      expect(formatOrderNumber(42), 'ADT-000042');
      expect(formatOrderNumber(999999), 'ADT-999999');
      expect(formatOrderNumber(1000000), 'ADT-1000000');
    });
  });
}
