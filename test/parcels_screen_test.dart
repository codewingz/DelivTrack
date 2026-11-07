import 'package:deliv_track/common_widgets/list_skeleton.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/views/parcels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

class _Calls {
  int adds = 0;
  final opened = <String>[];
}

Future<_Calls> _pump(WidgetTester t, FakeParcelRepository repo, {Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final calls = _Calls();
  await t.pumpWidget(MaterialApp(
    home: ParcelsScreen(
      repository: repo,
      onAdd: () async => calls.adds++,
      onOpen: (Parcel p) => calls.opened.add(p.id),
    ),
  ));
  await t.pump();
  await t.pump();
  return calls;
}

void main() {
  group('list', () {
    testWidgets('skeleton while loading, then parcels newest first with order number, chips, customer, reference, date and amount', (t) async {
      final repo = FakeParcelRepository(initial: [
        testParcel(id: 'a', sequence: 1, customerName: 'Ali Raza', reference: 'VPP 11111', sendingDate: '2026-11-05'),
        testParcel(id: 'b', sequence: 2, customerName: 'Sara Khan', method: CollectionMethod.payLater, service: PostalService.vpl, reference: 'VPL 22222', sendingDate: '2026-11-06'),
      ]);
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: ParcelsScreen(repository: repo, onAdd: () async {}, onOpen: (_) {})));
      expect(find.byType(ListSkeleton), findsOneWidget);
      await t.pump();
      await t.pump();
      expect(find.byType(ListSkeleton), findsNothing);

      final orders = t.widgetList<Text>(find.textContaining('ADT-')).map((w) => w.data).toList();
      expect(orders, ['ADT-000002', 'ADT-000001'], reason: 'newest first');
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('VPL · VPL 22222'), findsOneWidget);
      expect(find.text('6 Nov 2026 · Rs. 5,000'), findsOneWidget);
      expect(find.text('Sent'), findsNWidgets(2));
      expect(find.text('Pending'), findsNWidgets(2));
    });

    testWidgets('a draft without a slip, a gift parcel and an "Other" service read correctly', (t) async {
      await _pump(t, FakeParcelRepository(initial: [
        testParcel(id: 'd', sequence: 1, status: ParcelStatus.draft, reference: '', charge: null),
        testParcel(id: 'g', sequence: 2, method: CollectionMethod.giftFree, service: PostalService.vpl, reference: 'VPL 99999'),
        testParcel(id: 'o', sequence: 3, service: PostalService.other, otherName: 'Fast Courier', reference: 'XYZ 12345'),
      ]));
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('No postal reference yet'), findsOneWidget);
      expect(find.text('Not required'), findsOneWidget);
      expect(find.text('7 Nov 2026 · Gift / Free'), findsOneWidget);
      expect(find.text('Fast Courier · XYZ 12345'), findsOneWidget);
    });

    testWidgets('there is no search box yet (search is a later feature)', (t) async {
      await _pump(t, FakeParcelRepository(initial: [testParcel()]));
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('tapping a parcel opens it; Add Parcel calls onAdd', (t) async {
      final calls = await _pump(t, FakeParcelRepository(initial: [testParcel(id: 'abc', sequence: 7)]));
      await t.tap(find.text('ADT-000007'));
      expect(calls.opened, ['abc']);
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Parcel'));
      expect(calls.adds, 1);
    });

    testWidgets('empty account: guidance and an Add Parcel action', (t) async {
      final calls = await _pump(t, FakeParcelRepository());
      expect(find.text('No parcels yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Add Parcel'));
      expect(calls.adds, 1);
    });

    testWidgets('live updates appear without reloading', (t) async {
      final repo = FakeParcelRepository();
      await _pump(t, repo);
      expect(find.text('No parcels yet'), findsOneWidget);
      await repo.create(_inputFor(repo));
      await t.pump();
      await t.pump();
      expect(find.text('ADT-000001'), findsOneWidget);
    });

    testWidgets('load error: message and Retry', (t) async {
      final repo = FakeParcelRepository(initial: [testParcel()]);
      await _pump(t, repo);
      repo.emitError(const AppFailure('No internet connection.'));
      await t.pump();
      await t.pump();
      expect(find.text("Couldn't load the list"), findsOneWidget);
      expect(find.text('No internet connection.'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Retry'));
      await t.pump();
      await t.pump();
      expect(find.text('ADT-000001'), findsOneWidget);
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    final longName = 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman ${'x' * 5}';
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('rows and empty state do not overflow at $size text x$scale', (t) async {
          await _pump(
            t,
            FakeParcelRepository(initial: [
              testParcel(id: 'a', sequence: 1, customerName: longName, service: PostalService.other, otherName: 'A Very Long Courier Service Name', reference: 'ABCDEFGHIJ/1234567890-ABCDEFGHIJ'),
              testParcel(id: 'b', sequence: 2, status: ParcelStatus.draft, reference: '', charge: null),
            ]),
            size: size,
            scale: scale,
          );
          expect(t.takeException(), isNull);
        });

        testWidgets('empty list does not overflow at $size text x$scale', (t) async {
          await _pump(t, FakeParcelRepository(), size: size, scale: scale);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}

ParcelInput _inputFor(FakeParcelRepository repo) => ParcelInput(
      customer: const Customer(id: 'c1', name: 'Ali Raza', phone: '03001111111', address: 'House 5, Sahiwal'),
      items: [ParcelItem.pieces(productId: 'p', productName: 'Box', quantity: 1, unitPricePaisa: 1000)],
      method: CollectionMethod.advance,
      service: PostalService.vpl,
      status: ParcelStatus.draft,
    );
