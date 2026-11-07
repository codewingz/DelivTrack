import 'package:deliv_track/core/data/changed_keys.dart';
import 'package:deliv_track/core/money/money.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/payment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('changedKeys', () {
    test('lists added, removed and changed entries, sorted, and ignores equal values', () {
      final before = {'a': 1, 'b': 'x', 'c': true, 'gone': 5};
      final after = {'a': 1, 'b': 'y', 'c': true, 'new': 2};
      expect(changedKeys(before, after), ['b', 'gone', 'new']);
      expect(changedKeys(before, before), isEmpty);
    });

    test('compares nested maps and lists by value', () {
      final before = {
        'items': [
          {'id': 'p1', 'qty': 2}
        ],
        'customer': {'name': 'Ali', 'phone': '1'},
      };
      final same = {
        'items': [
          {'id': 'p1', 'qty': 2}
        ],
        'customer': {'name': 'Ali', 'phone': '1'},
      };
      final other = {
        'items': [
          {'id': 'p1', 'qty': 3}
        ],
        'customer': {'name': 'Ali', 'phone': '1'},
      };
      expect(changedKeys(before, same), isEmpty);
      expect(changedKeys(before, other), ['items']);
    });

    test('list order and length matter; null and missing are different from a value', () {
      expect(changedKeys({'l': [1, 2]}, {'l': [2, 1]}), ['l']);
      expect(changedKeys({'l': [1]}, {'l': [1, 2]}), ['l']);
      expect(changedKeys({'x': null}, {'x': 0}), ['x']);
    });
  });

  group('payment rules', () {
    test('outstanding is never negative', () {
      expect(outstandingFor(expectedPaisa: 1000, receivedPaisa: 0), 1000);
      expect(outstandingFor(expectedPaisa: 1000, receivedPaisa: 400), 600);
      expect(outstandingFor(expectedPaisa: 1000, receivedPaisa: 1000), 0);
      expect(outstandingFor(expectedPaisa: 1000, receivedPaisa: 1500), 0);
    });

    test('payment status', () {
      PaymentStatus status(int expected, int received, {bool free = false}) =>
          paymentStatusFor(isFree: free, expectedPaisa: expected, receivedPaisa: received);
      expect(status(1000, 0), PaymentStatus.pending);
      expect(status(1000, 1), PaymentStatus.partial);
      expect(status(1000, 999), PaymentStatus.partial);
      expect(status(1000, 1000), PaymentStatus.received);
      expect(status(1000, 5000), PaymentStatus.received);
      expect(status(0, 0, free: true), PaymentStatus.notRequired);
      expect(status(1000, 0, free: true), PaymentStatus.notRequired);
    });
  });

  group('plain number text for input fields', () {
    test('plainRupees', () {
      expect(plainRupees(0), '0');
      expect(plainRupees(250000), '2500');
      expect(plainRupees(250050), '2500.50');
      expect(plainRupees(5), '0.05');
      expect(plainRupees(maxMoneyPaisa), '99999999');
    });

    test('plainKg', () {
      expect(plainKg(1250), '1.25');
      expect(plainKg(2000), '2');
      expect(plainKg(5), '0.005');
      expect(plainKg(1500), '1.5');
      expect(plainKg(maxWeightGrams), '9999.999');
    });

    test('the text parses back to the same value', () {
      for (final paisa in [0, 1, 5, 50, 100, 250050, maxMoneyPaisa]) {
        expect(parseRupeesToPaisa(plainRupees(paisa)), paisa);
      }
      for (final grams in [1, 5, 500, 1250, 2000, maxWeightGrams]) {
        expect(parseKgToGrams(plainKg(grams)), grams);
      }
    });
  });
}
