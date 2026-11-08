import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/tab_finders.dart';

import 'package:google_nav_bar/google_nav_bar.dart';

import 'helpers/dropdown_finders.dart';

Finder _tab(String label) => tabButton(label);

Future<FakeParcelRepository> _launch(
  WidgetTester t, {
  FakeParcelRepository? parcels,
}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = parcels ?? FakeParcelRepository();
  await t.pumpWidget(
    DelivTrackApp(
      repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
      productRepository: FakeProductRepository(
        initial: [
          const Product(
            id: 'p1',
            name: 'Mango Box',
            saleUnit: SaleUnit.perPiece,
            isActive: true,
          ),
        ],
      ),
      customerRepository: FakeCustomerRepository(
        initial: [
          const Customer(
            id: 'c1',
            name: 'Ali Raza',
            phone: '03001111111',
            address: 'House 5, Sahiwal',
          ),
        ],
      ),
      parcelRepository: repo,
    ),
  );
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('bottom bar: Home, Parcels, Customers, More', (t) async {
    await _launch(t);
    for (final label in ['Home', 'Parcels', 'Customers', 'More']) {
      expect(_tab(label), findsOneWidget, reason: label);
    }
    await t.tap(_tab('Parcels'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
    expect(find.text('No parcels yet'), findsOneWidget);
  });

  testWidgets('tapping a parcel opens its details; back returns to the list', (
    t,
  ) async {
    await _launch(
      t,
      parcels: FakeParcelRepository(
        initial: [
          testParcel(id: 'abc', sequence: 5, customerName: 'Sara Khan'),
        ],
      ),
    );
    await t.tap(_tab('Parcels'));
    await t.pumpAndSettle();
    await t.tap(find.text('ADT-000005'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'ADT-000005'), findsOneWidget);
    expect(find.byType(GNav), findsNothing, reason: 'details is a full screen');
    expect(find.text('Sara Khan'), findsWidgets);

    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
  });

  testWidgets(
    'add a parcel end to end: list -> form -> save -> the NEW parcel\'s details open -> back to the list with the new row',
    (t) async {
      final repo = await _launch(t);
      await t.tap(_tab('Parcels'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Parcel'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add parcel'), findsOneWidget);

      // customer
      await t.tap(
        find.widgetWithText(TextFormField, 'Select a customer').first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Ali Raza'));
      await t.pumpAndSettle();
      // type
      await chooseOption(t, 'Parcel type', 'Advance paid');
      // product
      await t.ensureVisible(
        find.widgetWithText(TextFormField, 'Select a product').first,
      );
      await t.pump();
      await t.tap(find.widgetWithText(TextFormField, 'Select a product').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Mango Box'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Enter quantity'),
        '2',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Enter agreed price'),
        '100',
      );
      await t.pump();
      await t.ensureVisible(find.byType(FilledButton));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();

      expect(repo.parcels.single.orderNumber, 'ADT-000001');
      expect(
        find.widgetWithText(AppBar, 'ADT-000001'),
        findsOneWidget,
        reason: 'details of the new parcel open after saving',
      );
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Rs. 200'), findsWidgets);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
      expect(find.text('ADT-000001'), findsOneWidget);
    },
  );

  testWidgets(
    'leaving the Add parcel form without saving does not open any details',
    (t) async {
      await _launch(t);
      await t.tap(_tab('Parcels'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Parcel'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
    },
  );
}
