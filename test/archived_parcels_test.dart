import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/parcels/views/archived_parcels_screen.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

void main() {
  test(
    'Parcel.canArchive: only when nothing is left to chase, and never twice',
    () {
      expect(testParcel().canArchive, isFalse, reason: 'sent, owes Rs. 5,000');
      expect(testParcel(received: 500000).canArchive, isTrue);
      expect(
        testParcel(
          status: ParcelStatus.draft,
          reference: '',
          charge: null,
        ).canArchive,
        isTrue,
      );
      expect(
        testParcel(status: ParcelStatus.returned).canArchive,
        isTrue,
        reason: 'returned, nothing to review',
      );
      expect(
        testParcel(
          status: ParcelStatus.returned,
          paymentReviewRequired: true,
        ).canArchive,
        isFalse,
        reason: 'DT-003: payment review still open',
      );
      expect(testParcel(method: CollectionMethod.giftFree).canArchive, isTrue);
      expect(
        testParcel(received: 500000, isArchived: true).canArchive,
        isFalse,
        reason: 'already archived',
      );
    },
  );

  test('a returned parcel with an open payment review cannot be archived and stays on the lists', () async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'a',
          status: ParcelStatus.returned,
          received: 100000,
          paymentReviewRequired: true,
        ),
      ],
    );
    await expectLater(repo.archive('a'), throwsA(isA<AppFailure>()));
    final all = await repo.watchAll().first;
    expect(all.map((p) => p.id), ['a']);
    expect(
      all.single.receivedPaisa,
      100000,
      reason: 'the money is still counted',
    );
    expect(await repo.watchArchived().first, isEmpty);
  });

  test('completing the payment review makes a returned parcel archivable; the money is untouched', () async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'a',
          status: ParcelStatus.returned,
          received: 100000,
          paymentReviewRequired: true,
        ),
      ],
    );
    await repo.completePaymentReview(
      'a',
      resolution: ReviewResolution.balanceWaived,
      note: 'Customer refused, balance dropped',
      date: '2026-11-08',
    );
    final done = (await repo.watchAll().first).single;
    expect(done.canArchive, isTrue);
    expect(done.receivedPaisa, 100000);
    expect(done.reviewResolution, ReviewResolution.balanceWaived);
    await repo.archive('a');
    expect(await repo.watchAll().first, isEmpty);
    await expectLater(
      repo.completePaymentReview(
        'a',
        resolution: ReviewResolution.other,
        note: 'again again',
        date: '2026-11-08',
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('archived parcels leave watchAll and appear in watchArchived; restoring reverses it', () async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(id: 'a', sequence: 1, received: 500000),
        testParcel(id: 'b', sequence: 2),
      ],
    );
    expect((await repo.watchAll().first).map((p) => p.id), ['b', 'a']);
    await repo.archive('a');
    expect((await repo.watchAll().first).map((p) => p.id), ['b']);
    expect((await repo.watchArchived().first).map((p) => p.id), ['a']);
    await repo.restore('a');
    expect((await repo.watchAll().first).map((p) => p.id), ['b', 'a']);
  });

  testWidgets(
    'More -> Archived parcels lists them; a row opens the parcel; an empty list explains itself',
    (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            sequence: 1,
            customerName: 'Old Customer',
            received: 500000,
            isArchived: true,
          ),
        ],
      );
      await t.pumpWidget(
        DelivTrackApp(
          repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
          productRepository: FakeProductRepository(),
          customerRepository: FakeCustomerRepository(),
          parcelRepository: repo,
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Total parcels: 0'),
        findsOneWidget,
        reason: 'archived parcels are not counted',
      );
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Archived parcels'));
      await t.pumpAndSettle();
      expect(find.byType(ArchivedParcelsScreen), findsOneWidget);
      expect(find.text('Old Customer'), findsOneWidget);
      await t.tap(find.text('ADT-000001'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Restore Parcel'),
        findsOneWidget,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Restore Parcel'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('No archived parcels'), findsOneWidget);
    },
  );
}
