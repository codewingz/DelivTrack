import 'dart:async';

import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_search.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/parcels/viewmodel/parcel_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

Payment _payment(String id, DateTime when, {int amount = 100000}) => Payment(
  id: id,
  amountPaisa: amount,
  type: PaymentType.advance,
  note: null,
  receivedAt: when,
);

void main() {
  test(
    'search and filters narrow over every parcel, newest first, and combine',
    () async {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            sequence: 1,
            customerName: 'Ali Raza',
            method: CollectionMethod.advance,
          ),
          testParcel(id: 'b', sequence: 2, customerName: 'Ali Khan'),
          testParcel(
            id: 'c',
            sequence: 3,
            customerName: 'Sara Khan',
            method: CollectionMethod.advance,
          ),
        ],
      );
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      expect(vm.matching.map((p) => p.id), ['c', 'b', 'a']);
      expect(vm.isNarrowed, isFalse);

      vm.setQuery('ali');
      expect(vm.matching.map((p) => p.id), ['b', 'a']);
      vm.setFilters(const ParcelFilters(methods: {CollectionMethod.advance}));
      expect(vm.matching.map((p) => p.id), ['a'], reason: 'search AND filter');
      expect(vm.isNarrowed, isTrue);
      vm.clearAll();
      expect(vm.query, '');
      expect(vm.filters.isEmpty, isTrue);
      expect(vm.matching, hasLength(3));
      vm.dispose();
    },
  );

  test(
    '20 rows at a time; narrowing starts again from the first page',
    () async {
      final repo = FakeParcelRepository(
        initial: [
          for (var i = 1; i <= 45; i++) testParcel(id: 'p$i', sequence: i),
        ],
      );
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      expect(vm.visible, hasLength(20));
      expect(vm.hasMore, isTrue);
      vm.loadMore();
      expect(vm.visible, hasLength(40));
      vm.loadMore();
      expect(vm.visible, hasLength(45));
      expect(vm.hasMore, isFalse);
      vm.setQuery('ADT-0000');
      expect(
        vm.visible,
        hasLength(20),
        reason: 'a new search goes back to page one',
      );
      vm.dispose();
    },
  );

  test(
    'the product choices are every product on any parcel, once, by name',
    () async {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            sequence: 1,
            items: [
              ParcelItem.pieces(
                productId: 'p2',
                productName: 'Mango Box',
                quantity: 1,
                unitPricePaisa: 100,
              ),
            ],
          ),
          testParcel(
            id: 'b',
            sequence: 2,
            items: [
              ParcelItem.pieces(
                productId: 'p2',
                productName: 'Mango Box',
                quantity: 1,
                unitPricePaisa: 100,
              ),
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Dry Fruits',
                quantity: 1,
                unitPricePaisa: 100,
              ),
            ],
          ),
        ],
      );
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      expect(vm.products.map((p) => p.name), ['Dry Fruits', 'Mango Box']);
      vm.setFilters(const ParcelFilters(productId: 'p1'));
      expect(vm.matching.map((p) => p.id), ['b']);
      vm.dispose();
    },
  );

  group('payment date filter', () {
    FakeParcelRepository withPayments() {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(id: 'a', sequence: 1, received: 100000),
          testParcel(id: 'b', sequence: 2, received: 100000),
          testParcel(id: 'c', sequence: 3),
        ],
      );
      repo.payments['a'] = [_payment('a1', DateTime.utc(2026, 11, 8, 6))];
      repo.payments['b'] = [_payment('b1', DateTime.utc(2026, 10, 1, 6))];
      return repo;
    }

    test('fetches the dates once, only for parcels that received money, and filters by them', () async {
      final repo = withPayments();
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      vm.setFilters(
        const ParcelFilters(
          receivedFrom: '2026-11-01',
          receivedTo: '2026-11-30',
        ),
      );
      expect(vm.isLoadingPaymentDates, isTrue);
      expect(
        vm.matching,
        isEmpty,
        reason: 'nothing is shown while the dates load',
      );
      await settle();
      await settle();
      expect(vm.isLoadingPaymentDates, isFalse);
      expect(vm.matching.map((p) => p.id), ['a']);
      expect(repo.paymentDateLookups, 1);
      vm.setQuery('ADT');
      expect(
        repo.paymentDateLookups,
        1,
        reason: 'searching does not fetch again',
      );
      vm.dispose();
    });

    test('a reversed payment does not count', () async {
      final repo = FakeParcelRepository(
        initial: [testParcel(id: 'a', sequence: 1, received: 0)],
      );
      repo.payments['a'] = [
        Payment(
          id: 'rev_x',
          amountPaisa: -100000,
          type: PaymentType.advance,
          note: null,
          receivedAt: DateTime.utc(2026, 11, 9, 6),
          reversalOfPaymentId: 'x',
        ),
        _payment('x', DateTime.utc(2026, 11, 8, 6)),
      ];
      final vm = ParcelListViewModel(
        FakeParcelRepository(
          initial: [testParcel(id: 'a', sequence: 1, received: 100000)],
        )..payments['a'] = repo.payments['a']!,
        clock: const _Clock(),
      );
      await settle();
      vm.setFilters(const ParcelFilters(receivedFrom: '2026-11-01'));
      await settle();
      await settle();
      expect(vm.matching, isEmpty);
      vm.dispose();
    });

    test('a failure is kept and Retry fetches again', () async {
      final repo = withPayments();
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      repo.failure = const AppFailure('No internet connection.');
      vm.setFilters(const ParcelFilters(receivedFrom: '2026-11-01'));
      await settle();
      await settle();
      expect(vm.paymentDatesError, 'No internet connection.');
      expect(vm.isLoadingPaymentDates, isFalse);
      repo.failure = null;
      vm.retryPaymentDates();
      await settle();
      await settle();
      expect(vm.paymentDatesError, isNull);
      expect(vm.matching.map((p) => p.id), ['a']);
      vm.dispose();
    });

    test('an older lookup never overwrites a newer one', () async {
      final repo = withPayments();
      final vm = ParcelListViewModel(repo, clock: const _Clock());
      await settle();
      final gate = Completer<void>();
      repo.gate = gate;
      vm.setFilters(
        const ParcelFilters(
          receivedFrom: '2026-10-01',
          receivedTo: '2026-10-31',
        ),
      ); // waits on the gate
      await settle();
      repo.gate = null;
      vm.setFilters(
        const ParcelFilters(receivedFrom: '2026-11-01'),
      ); // newer lookup finishes first
      await settle();
      await settle();
      gate.complete();
      await settle();
      await settle();
      expect(vm.matching.map((p) => p.id), [
        'a',
      ], reason: 'the newer filter wins');
      vm.dispose();
    });

    test(
      'dropping the filter while a lookup runs ignores its late result',
      () async {
        final repo = withPayments();
        final vm = ParcelListViewModel(repo, clock: const _Clock());
        await settle();
        final gate = Completer<void>();
        repo.gate = gate;
        vm.setFilters(const ParcelFilters(receivedFrom: '2026-11-01'));
        vm.dispose();
        gate.complete();
        await settle();
        await settle();
      },
    );
  });
}
