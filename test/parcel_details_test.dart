import 'dart:async';
import 'package:deliv_track/common_widgets/list_skeleton.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/views/parcel_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

Future<void> _open(WidgetTester t, ParcelRepository repo, String id, {Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(MaterialApp(home: ParcelDetailsScreen(repository: repo, parcelId: id)));
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('a sent parcel shows every section with its data', (t) async {
    final repo = FakeParcelRepository(initial: [
      testParcel(
        id: 'a',
        sequence: 12,
        packedGrams: 3200,
        sendingDate: '2026-11-07',
        items: [
          ParcelItem.pieces(productId: 'x', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000),
          ParcelItem.weight(productId: 'y', productName: 'Dry Fruits', weightGrams: 1250, unitPricePaisa: 80000),
        ],
      ),
    ]);
    await _open(t, repo, 'a');
    expect(find.widgetWithText(AppBar, 'ADT-000012'), findsOneWidget);
    for (final text in [
      'Sent', 'Pending', '7 Nov 2026', 'Post office collection',
      'Ali Raza', '0300 1111111', 'House 5, Street 2, Sahiwal',
      'Mango Box', '2 pieces × Rs. 2,500 each = Rs. 5,000',
      'Dry Fruits', '1.25 kg × Rs. 800 per kg = Rs. 1,000',
      'VPP', 'VPP 12345', 'Rs. 150.50', '3.2 kg',
      'Rs. 6,000',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Rs. 0'), findsOneWidget, reason: 'received');
    expect(find.textContaining('Estimated payment date'), findsNothing);
  });

  testWidgets('a draft says what is still missing; no packed weight row', (t) async {
    final repo = FakeParcelRepository(initial: [testParcel(id: 'd', status: ParcelStatus.draft, reference: '', charge: null)]);
    await _open(t, repo, 'd');
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Not entered yet'), findsNWidgets(2), reason: 'reference and delivery charge');
    expect(find.text('Packed parcel weight'), findsNothing);
  });

  testWidgets('a gift parcel shows no payment expected and no prices', (t) async {
    final repo = FakeParcelRepository(initial: [
      testParcel(
        id: 'g',
        method: CollectionMethod.giftFree,
        service: PostalService.vpl,
        reference: 'VPL 99999',
        items: [ParcelItem.pieces(productId: 'x', productName: 'Mango Box', quantity: 3, unitPricePaisa: 0)],
      ),
    ]);
    await _open(t, repo, 'g');
    expect(find.text('Gift / Free'), findsOneWidget);
    expect(find.text('Not required'), findsOneWidget);
    expect(find.text('None (Gift / Free)'), findsOneWidget);
    expect(find.text('3 pieces'), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('Pay Later shows the estimated payment date; "Other" shows the typed service name', (t) async {
    final repo = FakeParcelRepository(initial: [
      testParcel(id: 'p', method: CollectionMethod.payLater, service: PostalService.other, otherName: 'Fast Courier', reference: 'ABC 12345', payDate: '2026-12-25'),
    ]);
    await _open(t, repo, 'p');
    expect(find.text('Pay Later'), findsOneWidget);
    expect(find.text('25 Dec 2026'), findsOneWidget);
    expect(find.text('Fast Courier'), findsOneWidget);
  });

  testWidgets('skeleton first; an unknown id says not found', (t) async {
    final repo = FakeParcelRepository();
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: ParcelDetailsScreen(repository: repo, parcelId: 'nope')));
    expect(find.byType(ListSkeleton), findsOneWidget);
    await t.pump();
    await t.pump();
    expect(find.text('This parcel was not found'), findsOneWidget);
  });

  testWidgets('a load failure shows the message and Retry loads it', (t) async {
    final repo = _FlakyRepository(testParcel(id: 'a', sequence: 3));
    await _open(t, repo, 'a');
    expect(find.text("Couldn't load this parcel"), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Retry'));
    await t.pump();
    await t.pump();
    expect(find.widgetWithText(AppBar, 'ADT-000003'), findsOneWidget);
  });

  testWidgets('a parcel created through the repository can be opened', (t) async {
    final repo = FakeParcelRepository();
    await repo.create(ParcelInput(
      customer: const Customer(id: 'c1', name: 'Ali Raza', phone: '03001111111', address: 'House 5, Sahiwal'),
      items: [ParcelItem.pieces(productId: 'p', productName: 'Box', quantity: 1, unitPricePaisa: 1000)],
      method: CollectionMethod.advance,
      service: PostalService.vpl,
      status: ParcelStatus.draft,
    ));
    await _open(t, repo, 'parcel-1');
    expect(find.text('Draft'), findsOneWidget);
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('does not overflow at $size text x$scale', (t) async {
          final repo = FakeParcelRepository(initial: [
            testParcel(
              id: 'a',
              customerName: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman',
              customerAddress: 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab',
              service: PostalService.other,
              otherName: 'A Very Long Courier Service Name',
              method: CollectionMethod.payLater,
              payDate: '2026-12-25',
              packedGrams: 9999999,
              items: [
                ParcelItem.pieces(productId: 'x', productName: 'Premium Gift Hamper With A Very Long Descriptive Name', quantity: 99999, unitPricePaisa: 9999999900),
                ParcelItem.weight(productId: 'y', productName: 'Dry Fruits', weightGrams: 9999999, unitPricePaisa: 123456789),
              ],
            ),
          ]);
          await _open(t, repo, 'a', size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}

/// First load fails, the next one works.
class _FlakyRepository extends FakeParcelRepository {
  _FlakyRepository(this._parcel);
  final Parcel _parcel;
  int calls = 0;

  @override
  Stream<Parcel?> watch(String id) {
    calls++;
    if (calls == 1) return Stream<Parcel?>.error(const AppFailure('No internet connection.'));
    return Stream.value(_parcel);
  }
}
