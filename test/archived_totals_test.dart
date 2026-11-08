// DT-010: archiving is organisational, not a financial event.
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customer_details_screen.dart';
import 'package:deliv_track/features/dashboard/domain/dashboard_stats.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/payments/domain/payment_tabs.dart';
import 'package:deliv_track/features/payments/viewmodel/payments_view_model.dart';
import 'package:deliv_track/features/reports/domain/reports.dart';
import 'package:deliv_track/features/reports/viewmodel/report_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

void main() {
  FakeParcelRepository repo() => FakeParcelRepository(
    initial: [
      testParcel(id: 'open', sequence: 1), // owes Rs. 5,000
      testParcel(id: 'paid', sequence: 2, received: 500000), // paid in full
      testParcel(
        id: 'adv',
        sequence: 3,
        method: CollectionMethod.advance,
        service: PostalService.vpl,
        received: 200000,
      ),
    ],
  );

  group('dashboard figures', () {
    test('archiving a paid parcel moves it out of the counts but not out of Total received', () async {
      final r = repo();
      final before = DashboardStats.from(
        await r.watchAll(includeArchived: true).first,
        _today,
      );
      await r.archive('paid');
      final after = DashboardStats.from(
        await r.watchAll(includeArchived: true).first,
        _today,
      );
      expect(before.totalReceivedPaisa, 700000);
      expect(
        after.totalReceivedPaisa,
        700000,
        reason: 'archiving is not a payment reversal',
      );
      expect(
        after.totalParcels,
        before.totalParcels - 1,
        reason: 'counts are active parcels',
      );
      expect(after.paymentReceived, before.paymentReceived - 1);
      expect(
        after.totalOutstandingPaisa,
        before.totalOutstandingPaisa,
        reason: 'a paid parcel owed nothing',
      );
      expect(after.recent.map((p) => p.id), isNot(contains('paid')));
    });

    test('restoring does not count the money twice', () async {
      final r = repo();
      await r.archive('paid');
      await r.restore('paid');
      final stats = DashboardStats.from(
        await r.watchAll(includeArchived: true).first,
        _today,
      );
      expect(stats.totalReceivedPaisa, 700000);
      expect(stats.totalParcels, 3);
    });

    test(
      'only the user\'s own parcels are summed: two repositories never mix',
      () async {
        final mine = repo();
        final theirs = FakeParcelRepository(
          initial: [testParcel(id: 'x', received: 100000, isArchived: true)],
        );
        final a = DashboardStats.from(
          await mine.watchAll(includeArchived: true).first,
          _today,
        );
        final b = DashboardStats.from(
          await theirs.watchAll(includeArchived: true).first,
          _today,
        );
        expect(a.totalReceivedPaisa, 700000);
        expect(b.totalReceivedPaisa, 100000);
        expect(b.totalParcels, 0);
      },
    );
  });

  group('payments tab', () {
    test(
      'totals keep archived advance money; the lists show active parcels only',
      () async {
        final r = FakeParcelRepository(
          initial: [
            testParcel(
              id: 'adv',
              sequence: 1,
              method: CollectionMethod.advance,
              service: PostalService.vpl,
              received: 500000,
              isArchived: true,
            ),
            testParcel(id: 'open', sequence: 2),
          ],
        );
        final vm = PaymentsViewModel(r);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(vm.totals.advancePaisa, 500000);
        for (final tab in PaymentTab.values) {
          vm.select(tab);
          expect(
            vm.matching.where((p) => p.isArchived),
            isEmpty,
            reason: tab.name,
          );
        }
        vm.dispose();
      },
    );
  });

  group('payment received history', () {
    test('includes the payments of archived parcels and its total reconciles with the ledger', () async {
      final r = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'paid',
            sequence: 1,
            received: 500000,
            isArchived: true,
          ),
          testParcel(id: 'part', sequence: 2, received: 100000),
        ],
      );
      r.payments['paid'] = [
        Payment(
          id: 'p1',
          amountPaisa: 500000,
          type: PaymentType.customerPayment,
          note: null,
          receivedAt: DateTime.utc(2026, 11, 9, 7),
        ),
      ];
      r.payments['part'] = [
        Payment(
          id: 'p2',
          amountPaisa: 100000,
          type: PaymentType.advance,
          note: null,
          receivedAt: DateTime.utc(2026, 11, 9, 8),
        ),
      ];
      final vm = ReportViewModel(r, ReportType.paymentHistory);
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final result = vm.result!;
      expect(
        result.rows.length,
        2,
        reason: 'the archived parcel\'s payment is still in the history',
      );
      expect(
        result.totals.join(' '),
        contains('6,000'),
        reason: 'Rs. 5,000 + Rs. 1,000',
      );
      vm.dispose();
    });

    test('other reports stay on active parcels', () async {
      final r = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'back',
            sequence: 1,
            status: ParcelStatus.returned,
            isArchived: true,
          ),
          testParcel(
            id: 'live',
            sequence: 2,
            status: ParcelStatus.returned,
            paymentReviewRequired: true,
          ),
        ],
      );
      final vm = ReportViewModel(r, ReportType.returned);
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(vm.result!.rows.map((row) => row.parcelId), ['live']);
      vm.dispose();
    });
  });

  group('customer details', () {
    testWidgets(
      'lifetime advance includes archived parcels; the history and the count are active only',
      (t) async {
        t.view.physicalSize = const Size(393, 1600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final parcels = FakeParcelRepository(
          initial: [
            testParcel(
              id: 'old',
              sequence: 1,
              method: CollectionMethod.advance,
              service: PostalService.vpl,
              received: 500000,
              isArchived: true,
            ),
            testParcel(id: 'now', sequence: 2),
          ],
        );
        await t.pumpWidget(
          MaterialApp(
            home: CustomerDetailsScreen(
              customerRepository: FakeCustomerRepository(
                initial: [
                  const Customer(
                    id: 'c1',
                    name: 'Ali Raza',
                    phone: '0300 1111111',
                    address: 'House 5, Sahiwal',
                  ),
                ],
              ),
              parcelRepository: parcels,
              customerId: 'c1',
              onEdit: (c) async => c.id,
              onOpenParcel: (_) {},
            ),
          ),
        );
        await t.pump();
        await t.pump();
        await t.pump();
        expect(
          find.bySemanticsLabel('Advance received: Rs. 5,000'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Parcels: 1'), findsOneWidget);
        expect(
          find.text('ADT-000001'),
          findsNothing,
          reason: 'the archived parcel is not in the history',
        );
        expect(find.text('ADT-000002'), findsWidgets);
      },
    );
  });
}
