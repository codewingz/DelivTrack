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
import 'helpers/tab_finders.dart';

void main() {
  test(
    'Parcel.canArchive: only a draft that received no money, and never twice',
    () {
      const draft = ParcelStatus.draft;
      expect(
        testParcel(status: draft, reference: '', charge: null).canArchive,
        isTrue,
      );
      expect(
        testParcel(
          status: draft,
          reference: '',
          charge: null,
          method: CollectionMethod.advance,
          received: 500000,
        ).canArchive,
        isFalse,
        reason: 'a paid draft',
      );
      expect(testParcel().canArchive, isFalse, reason: 'handed over');
      expect(
        testParcel(received: 500000).canArchive,
        isFalse,
        reason: 'paid in full',
      );
      expect(
        testParcel(status: ParcelStatus.returned).canArchive,
        isFalse,
        reason: 'returned parcels were handed over',
      );
      expect(testParcel(method: CollectionMethod.giftFree).canArchive, isFalse);
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

  test('completing the payment review leaves the money untouched; a returned parcel is never archived', () async {
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
    expect(done.canArchive, isFalse);
    expect(done.receivedPaisa, 100000);
    expect(done.reviewResolution, ReviewResolution.balanceWaived);
    await expectLater(repo.archive('a'), throwsA(isA<AppFailure>()));
  });

  test('archived parcels leave watchAll and appear in watchArchived; restoring reverses it', () async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'a',
          sequence: 1,
          status: ParcelStatus.draft,
          reference: '',
          charge: null,
        ),
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
      await t.tap(tabButton('More'));
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

  testWidgets(
    'the archived list shows the count, searches, and Restore brings a parcel back',
    (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = FakeParcelRepository(
        initial: [
          for (final (id, seq, name) in [
            ('a', 1, 'Old Customer'),
            ('b', 2, 'Sara Khan'),
          ])
            testParcel(
              id: id,
              sequence: seq,
              customerName: name,
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
              isArchived: true,
            ),
        ],
      );
      await t.pumpWidget(
        MaterialApp(
          home: ArchivedParcelsScreen(repository: repo, onOpen: (_) {}),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text('2 archived parcels'), findsOneWidget);
      expect(find.text('Archived'), findsNWidgets(2));

      await t.enterText(find.byType(TextFormField), 'sara');
      await t.pump();
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Old Customer'), findsNothing);

      await t.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await t.pumpAndSettle();
      expect(find.text('ADT-000002 restored.'), findsOneWidget);
      expect((await repo.watchArchived().first).map((p) => p.id), ['a']);
    },
  );
}
