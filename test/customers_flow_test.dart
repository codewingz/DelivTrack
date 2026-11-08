import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/tab_finders.dart';

import 'package:google_nav_bar/google_nav_bar.dart';

Future<FakeCustomerRepository> _launch(
  WidgetTester t, {
  List<Customer> customers = const [],
}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = FakeCustomerRepository(initial: customers);
  await t.pumpWidget(
    DelivTrackApp(
      repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
      productRepository: FakeProductRepository(),
      customerRepository: repo,
      parcelRepository: FakeParcelRepository(),
    ),
  );
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
  return repo;
}

Finder get _customersTab => tabButton('Customers');
Finder get _fields => find.byType(TextFormField);

void main() {
  testWidgets(
    'bottom bar has Home, Customers and More; Customers opens the list',
    (t) async {
      await _launch(t);
      expect(tabButton('Home'), findsOneWidget);
      expect(tabButton('More'), findsOneWidget);
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Customers'), findsOneWidget);
      expect(find.text('No customers yet'), findsOneWidget);
    },
  );

  testWidgets(
    'add a customer end to end: list -> full-screen form -> save -> back on the list with the new row',
    (t) async {
      final repo = await _launch(t);
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget);
      expect(
        find.byType(GNav),
        findsNothing,
        reason: 'the form is a full screen',
      );

      await t.enterText(_fields.at(0), 'Sara Khan');
      await t.enterText(_fields.at(1), '0301 2222222');
      await t.enterText(_fields.at(2), 'Street 3, Sahiwal');
      await t.ensureVisible(find.byType(FilledButton));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();

      expect(repo.items.single.name, 'Sara Khan');
      expect(find.widgetWithText(AppBar, 'Customers'), findsOneWidget);
      expect(find.text('Customer added.'), findsOneWidget);
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.byType(GNav), findsOneWidget);
    },
  );

  testWidgets(
    'edit a customer end to end: tap row -> prefilled form -> save -> updated row + confirmation',
    (t) async {
      final repo = await _launch(
        t,
        customers: [
          const Customer(
            id: 'c1',
            name: 'Ali Raza',
            phone: '03001111111',
            address: 'Old address 1',
          ),
        ],
      );
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      await t.tap(find.text('Ali Raza'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Ali Raza'),
        findsOneWidget,
        reason: 'the row opens the customer\'s details first',
      );
      await t.tap(find.byTooltip('Edit customer'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Edit customer'), findsOneWidget);
      expect(
        t.widget<TextFormField>(_fields.at(2)).controller!.text,
        'Old address 1',
      );

      await t.enterText(_fields.at(2), 'New address 99, Lahore');
      await t.ensureVisible(find.byType(FilledButton));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();

      expect(repo.items.single.address, 'New address 99, Lahore');
      expect(find.text('Customer updated.'), findsOneWidget);
      expect(
        find.textContaining('New address 99, Lahore'),
        findsOneWidget,
        reason: 'the details show the new address',
      );
    },
  );

  testWidgets(
    'leaving the add form with typed text asks first; Discard returns to the list without a confirmation',
    (t) async {
      final repo = await _launch(t);
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
      await t.pumpAndSettle();
      await t.enterText(_fields.at(0), 'Half typed');
      await t.pump();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Discard'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Customers'), findsOneWidget);
      expect(find.text('Customer added.'), findsNothing);
      expect(repo.items, isEmpty);
    },
  );

  testWidgets(
    'tab state: Home -> Customers -> More -> Customers keeps the search text and list',
    (t) async {
      await _launch(
        t,
        customers: [
          const Customer(
            id: 'c1',
            name: 'Ali Raza',
            phone: '03001111111',
            address: 'House 1, Sahiwal',
          ),
        ],
      );
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'ali');
      await t.pump();
      await t.tap(tabButton('More'));
      await t.pumpAndSettle();
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'ali',
      );
      expect(find.text('Ali Raza'), findsOneWidget);
    },
  );

  testWidgets(
    'the "Customer added." message never covers the Add Customer button',
    (t) async {
      await _launch(t);
      await t.tap(_customersTab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
      await t.pumpAndSettle();
      await t.enterText(_fields.at(0), 'Sara Khan');
      await t.enterText(_fields.at(1), '0301 2222222');
      await t.enterText(_fields.at(2), 'Street 3, Sahiwal');
      await t.ensureVisible(find.byType(FilledButton));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();

      final snackBar = t.getRect(find.byType(SnackBar));
      final fab = t.getRect(
        find.widgetWithText(FloatingActionButton, 'Add Customer'),
      );
      expect(
        snackBar.overlaps(fab),
        isFalse,
        reason: 'snackbar $snackBar must not overlap the button $fab',
      );
      final bar = t.getRect(find.byType(GNav));
      expect(
        snackBar.overlaps(bar),
        isFalse,
        reason: 'snackbar must sit above the tab bar',
      );
    },
  );
}
