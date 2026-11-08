import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/payments/domain/payment_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

Set<PaymentTab> tabsOf(Parcel p) => {
  for (final tab in PaymentTab.values)
    if (tab.includes(p, _today)) tab,
};

void main() {
  group('which lists a parcel belongs to', () {
    test('unpaid Post office collection: Pending and Post office', () {
      expect(tabsOf(testParcel()), {PaymentTab.pending, PaymentTab.postOffice});
    });

    test('part paid: Partially paid; paid in full: Received', () {
      expect(tabsOf(testParcel(received: 100000)), {
        PaymentTab.partial,
        PaymentTab.postOffice,
      });
      expect(tabsOf(testParcel(received: 500000)), {
        PaymentTab.received,
        PaymentTab.postOffice,
      });
    });

    test('Advance parcels are also listed under Advance whatever their payment state', () {
      expect(tabsOf(testParcel(method: CollectionMethod.advance)), {
        PaymentTab.pending,
        PaymentTab.advance,
      });
      expect(
        tabsOf(testParcel(method: CollectionMethod.advance, received: 500000)),
        {PaymentTab.received, PaymentTab.advance},
      );
    });

    test('Pay Later: Pay Later list plus its payment state; overdue only with a past date', () {
      PaymentTab pl = PaymentTab.payLater;
      expect(
        tabsOf(
          testParcel(method: CollectionMethod.payLater, payDate: '2026-11-10'),
        ),
        {PaymentTab.pending, pl},
        reason: 'due today is not overdue',
      );
      expect(
        tabsOf(
          testParcel(method: CollectionMethod.payLater, payDate: '2026-11-09'),
        ),
        {PaymentTab.pending, pl, PaymentTab.overdue},
      );
      expect(
        tabsOf(
          testParcel(method: CollectionMethod.payLater, payDate: '2026-12-01'),
        ),
        {PaymentTab.pending, pl},
      );
      expect(tabsOf(testParcel(method: CollectionMethod.payLater)), {
        PaymentTab.pending,
        pl,
      }, reason: 'no date: unpaid, never overdue');
      expect(
        tabsOf(
          testParcel(
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
            received: 100000,
          ),
        ),
        {PaymentTab.partial, pl, PaymentTab.overdue},
      );
      expect(
        tabsOf(
          testParcel(
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
            received: 500000,
          ),
        ),
        {PaymentTab.received},
        reason: 'paid in full leaves Pay Later and Overdue',
      );
    });

    test('Post office lists every collection parcel except returned ones (which are under Review)', () {
      expect(
        PaymentTab.postOffice.includes(
          testParcel(method: CollectionMethod.advance),
          _today,
        ),
        isFalse,
      );
      expect(
        PaymentTab.postOffice.includes(
          testParcel(method: CollectionMethod.payLater),
          _today,
        ),
        isFalse,
      );
      expect(
        PaymentTab.postOffice.includes(
          testParcel(
            status: ParcelStatus.returned,
            paymentReviewRequired: true,
          ),
          _today,
        ),
        isFalse,
      );
    });

    test('Gift / Free is never listed', () {
      expect(tabsOf(testParcel(method: CollectionMethod.giftFree)), isEmpty);
    });

    test('returned parcels appear only under Review, and only when review is required', () {
      expect(
        tabsOf(
          testParcel(
            status: ParcelStatus.returned,
            paymentReviewRequired: true,
          ),
        ),
        {PaymentTab.review},
      );
      expect(
        tabsOf(
          testParcel(
            status: ParcelStatus.returned,
            paymentReviewRequired: true,
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
          ),
        ),
        {PaymentTab.review},
      );
      expect(tabsOf(testParcel(status: ParcelStatus.returned)), isEmpty);
    });
  });

  group('PaymentTotals', () {
    test('outstanding, Pay Later balance and advance received; Gift / Free and returned are left out', () {
      final totals = PaymentTotals.from([
        testParcel(id: 'a'), // 5,000 owed
        testParcel(id: 'b', received: 200000), // 3,000 owed
        testParcel(
          id: 'c',
          method: CollectionMethod.payLater,
        ), // 5,000 owed on Pay Later
        testParcel(
          id: 'd',
          method: CollectionMethod.payLater,
          received: 100000,
        ), // 4,000
        testParcel(
          id: 'e',
          method: CollectionMethod.advance,
          received: 300000,
        ), // 2,000 owed, 3,000 advance
        testParcel(id: 'f', method: CollectionMethod.giftFree),
        testParcel(
          id: 'g',
          status: ParcelStatus.returned,
          paymentReviewRequired: true,
        ), // not counted
      ]);
      expect(
        totals.outstandingPaisa,
        500000 + 300000 + 500000 + 400000 + 200000,
      );
      expect(totals.payLaterPaisa, 500000 + 400000);
      expect(totals.advancePaisa, 300000);
    });

    test('empty list is all zero', () {
      final totals = PaymentTotals.from(const []);
      expect(
        [totals.outstandingPaisa, totals.payLaterPaisa, totals.advancePaisa],
        [0, 0, 0],
      );
    });
  });
}
