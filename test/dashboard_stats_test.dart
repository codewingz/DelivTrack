import 'package:deliv_track/features/dashboard/domain/dashboard_stats.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

void main() {
  test('an empty database is all zeros', () {
    final s = DashboardStats.from(const [], _today);
    expect([
      s.totalParcels,
      s.sent,
      s.returned,
      s.freeGift,
      s.paymentReceived,
      s.pendingPayment,
      s.needsReview,
      s.dueToday,
      s.overdue,
    ], everyElement(0));
    expect([
      s.totalReceivedPaisa,
      s.totalOutstandingPaisa,
      s.payLaterBalancePaisa,
      s.advancePaisa,
    ], everyElement(0));
    expect(s.recent, isEmpty);
  });

  test('counts: parcels, never payment transactions; each card equals the list it opens', () {
    final parcels = [
      testParcel(id: 'a', sequence: 1), // sent, pending, 5,000 owed
      testParcel(id: 'b', sequence: 2, received: 100000), // sent, partial
      testParcel(id: 'c', sequence: 3, received: 500000), // sent, received
      testParcel(
        id: 'd',
        sequence: 4,
        status: ParcelStatus.draft,
        reference: '',
        charge: null,
      ), // draft, pending
      testParcel(
        id: 'e',
        sequence: 5,
        method: CollectionMethod.giftFree,
      ), // free
      testParcel(
        id: 'f',
        sequence: 6,
        status: ParcelStatus.returned,
        received: 200000,
        paymentReviewRequired: true,
      ),
    ];
    final s = DashboardStats.from(parcels, _today);
    expect(s.totalParcels, 6);
    expect(
      s.sent,
      4,
      reason: 'a, b, c and the Gift / Free parcel e (a returned or draft parcel is not Sent)',
    );
    expect(s.returned, 1);
    expect(s.freeGift, 1);
    expect(
      s.paymentReceived,
      3,
      reason: 'b (partial), c (received) and the returned f (partial): parcels with money, not payments',
    );
    expect(s.pendingPayment, 2, reason: 'a and the draft d');
    for (final (list, number) in [
      (DashboardLists.sent, s.sent),
      (DashboardLists.returned, s.returned),
      (DashboardLists.freeGift, s.freeGift),
      (DashboardLists.paymentReceived, s.paymentReceived),
      (DashboardLists.pendingPayment, s.pendingPayment),
    ]) {
      expect(parcels.where((p) => list.matches(p, _today)).length, number);
    }
  });

  test('money: Free excluded from outstanding; returned money stays in Total received but its debt is not outstanding', () {
    final s = DashboardStats.from([
      testParcel(id: 'a', sequence: 1), // owes 5,000
      testParcel(id: 'b', sequence: 2, received: 100000), // owes 4,000
      testParcel(id: 'f', sequence: 3, method: CollectionMethod.giftFree),
      testParcel(
        id: 'r',
        sequence: 4,
        status: ParcelStatus.returned,
        received: 200000,
        paymentReviewRequired: true,
      ), // would owe 3,000
    ], _today);
    expect(
      s.totalOutstandingPaisa,
      500000 + 400000,
      reason: 'no Free, no returned',
    );
    expect(
      s.totalReceivedPaisa,
      100000 + 200000,
      reason: 'the returned parcel\'s money is still counted',
    );
    expect(
      s.needsReview,
      1,
      reason: 'and the returned parcel is flagged, not dropped',
    );
  });

  test('Pay Later balance and Advance amount are separate; Advance money counts once', () {
    final s = DashboardStats.from([
      testParcel(
        id: 'a',
        sequence: 1,
        method: CollectionMethod.payLater,
        received: 100000,
      ), // owes 4,000
      testParcel(
        id: 'b',
        sequence: 2,
        method: CollectionMethod.payLater,
      ), // owes 5,000
      testParcel(
        id: 'c',
        sequence: 3,
        method: CollectionMethod.advance,
        received: 300000,
      ), // owes 2,000, 3,000 received
      testParcel(
        id: 'd',
        sequence: 4,
        method: CollectionMethod.advance,
        received: 500000,
      ), // paid
    ], _today);
    expect(s.payLaterBalancePaisa, 400000 + 500000);
    expect(s.advancePaisa, 300000 + 500000);
    expect(
      s.totalReceivedPaisa,
      100000 + 300000 + 500000,
      reason: 'each rupee once, whichever card it also feeds',
    );
    expect(s.totalOutstandingPaisa, 400000 + 500000 + 200000);
  });

  test(
    'reminders: due today and overdue are counted from the Pay Later dates',
    () {
      final s = DashboardStats.from([
        testParcel(
          id: 'a',
          sequence: 1,
          method: CollectionMethod.payLater,
          payDate: '2026-11-10',
        ),
        testParcel(
          id: 'b',
          sequence: 2,
          method: CollectionMethod.payLater,
          payDate: '2026-11-01',
        ),
        testParcel(
          id: 'c',
          sequence: 3,
          method: CollectionMethod.payLater,
          payDate: '2026-11-05',
        ),
        testParcel(
          id: 'd',
          sequence: 4,
          method: CollectionMethod.payLater,
          payDate: '2026-12-01',
        ),
        testParcel(id: 'e', sequence: 5, method: CollectionMethod.payLater),
      ], _today);
      expect((s.dueToday, s.overdue), (1, 2));
    },
  );

  test('recent parcels: the 5 newest, newest first', () {
    final s = DashboardStats.from([
      for (var i = 1; i <= 8; i++) testParcel(id: 'p$i', sequence: i),
    ], _today);
    expect(s.recent.map((p) => p.id), ['p8', 'p7', 'p6', 'p5', 'p4']);
  });

  test('large amounts add up without overflow', () {
    final s = DashboardStats.from([
      for (var i = 1; i <= 50; i++)
        testParcel(id: 'p$i', sequence: i, received: 100000000),
    ], _today);
    expect(s.totalReceivedPaisa, 50 * 100000000);
  });

  test('drafts are counted as awaiting handover (active ones only); owing parcels are those that still owe money', () {
    final parcels = [
      testParcel(
        id: 'a',
        sequence: 1,
        status: ParcelStatus.draft,
        reference: '',
        charge: null,
      ),
      testParcel(
        id: 'b',
        sequence: 2,
        status: ParcelStatus.draft,
        reference: '',
        charge: null,
        isArchived: true,
      ),
      testParcel(id: 'c', sequence: 3), // sent, owes Rs. 5,000
      testParcel(id: 'd', sequence: 4, received: 500000), // paid in full
      testParcel(id: 'e', sequence: 5, method: CollectionMethod.giftFree),
      testParcel(
        id: 'f',
        sequence: 6,
        status: ParcelStatus.returned,
        paymentReviewRequired: true,
      ),
    ];
    final s = DashboardStats.from(parcels, _today);
    expect(s.awaitingHandover, 1, reason: 'the archived draft is not counted');
    expect(
      DashboardLists.awaitingHandover.matches(parcels.first, _today),
      isTrue,
    );
    expect(
      parcels
          .where(
            (p) =>
                DashboardLists.awaitingHandover.matches(p, _today) &&
                !p.isArchived,
          )
          .length,
      s.awaitingHandover,
    );
    expect(
      s.owingParcels,
      2,
      reason: 'the draft (owes its order total) and the sent parcel; not paid, Gift or returned',
    );
  });
}
