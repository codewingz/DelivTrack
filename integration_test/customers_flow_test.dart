// Full-app Customers flow through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/customers_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

Finder get _customersTab => find.descendant(of: find.byType(NavigationBar), matching: find.text('Customers'));
Finder get _fields => find.byType(TextFormField);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  Future<void> fillForm(WidgetTester t, {required String name, required String phone, required String address}) async {
    await typeInto(t, _fields.at(0), name);
    await typeInto(t, _fields.at(1), phone);
    await typeInto(t, _fields.at(2), address);
  }

  Future<void> openAddForm(WidgetTester t) async {
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add customer'));
    await t.pumpAndSettle();
  }

  testWidgets('owner manages customers through the UI; a second user sees none of them', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    await auth.signUp(name: 'Owner One', email: 'cone${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: FirestoreCustomerRepository(),
      parcelRepository: FirestoreParcelRepository(),
    ));
    await pumpUntil(t, find.text('Welcome, Owner One'));
    await t.tap(_customersTab);
    await pumpUntil(t, find.text('No customers yet'));

    // Validation first: empty form, then bad phone / short address.
    await openAddForm(t);
    await tapVisible(t, find.byType(FilledButton));
    await t.pump();
    expect(find.text('Customer name is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Full address is required'), findsOneWidget);
    await fillForm(t, name: 'Ali Raza', phone: '12345', address: 'abcd');
    await tapVisible(t, find.byType(FilledButton));
    await t.pump();
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('Enter the full address (5–200 characters)'), findsOneWidget);

    // Valid add -> back on the list with a confirmation and the new row.
    await fillForm(t, name: '  Ali   Raza ', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add customer'));
    await pumpUntil(t, find.text('Customer added.'));
    await pumpUntil(t, find.text('Ali Raza'));
    expect(find.textContaining('+92 300 1111111'), findsOneWidget);

    // Same number written differently -> duplicate warning; Cancel stays, Save anyway saves.
    await openAddForm(t);
    await fillForm(t, name: 'Ali Brother', phone: '03001111111', address: 'Another house 9, Sahiwal');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntil(t, find.text('A customer with this number already exists: Ali Raza. Save anyway?'));
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget);
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntil(t, find.widgetWithText(TextButton, 'Save anyway'));
    await t.tap(find.widgetWithText(TextButton, 'Save anyway'));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add customer'));
    await pumpUntil(t, find.text('Ali Brother'));

    // A different number saves with no warning.
    await openAddForm(t);
    await fillForm(t, name: 'Sara Khan', phone: '0301-2222222', address: 'Shop 4, Main Bazaar, Lahore');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add customer'));
    await pumpUntil(t, find.text('Sara Khan'));

    // Edit: prefilled; changing the address keeps the (own) phone without a warning.
    await t.tap(find.text('Sara Khan'));
    await pumpUntil(t, find.text('Parcel history'));
    await t.tap(find.byTooltip('Edit customer'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Edit customer'));
    await t.pumpAndSettle();
    expect(t.widget<TextFormField>(_fields.at(0)).controller!.text, 'Sara Khan');
    await typeInto(t, _fields.at(2), 'New shop 77, Model Town, Lahore');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Edit customer'));
    await pumpUntil(t, find.textContaining('New shop 77, Model Town, Lahore'));
    await pumpUntil(t, find.text('Customer updated.'));
    await t.pageBack(); // from the details back to the list
    await pumpUntil(t, find.widgetWithText(AppBar, 'Customers'));
    await t.pumpAndSettle();

    // Search by phone digits in another format, then by name.
    await t.enterText(find.byType(TextFormField).first, '+92 301 2222');
    await t.pump();
    expect(find.text('Sara Khan'), findsOneWidget);
    expect(find.text('Ali Raza'), findsNothing);
    await t.enterText(find.byType(TextFormField).first, 'brother');
    await t.pump();
    expect(find.text('Ali Brother'), findsOneWidget);
    expect(find.text('Sara Khan'), findsNothing);
    await t.tap(find.byTooltip('Clear'));
    await t.pump();

    // Unsaved typing asks before leaving.
    await openAddForm(t);
    await typeInto(t, _fields.at(0), 'Half typed');
    await t.pump();
    await t.pageBack();
    await pumpUntil(t, find.text('Discard changes?'));
    await t.tap(find.widgetWithText(TextButton, 'Discard'));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add customer'));

    // Log out; a different user sees an empty list and can reuse the same details.
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle(); // like a person: the logout transition finishes before anyone logs in again
    await auth.signUp(name: 'Owner Two', email: 'ctwo${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Owner Two'));
    await t.tap(_customersTab);
    await t.pump(const Duration(seconds: 4));
    await pumpUntil(t, find.text('No customers yet'));
    expect(find.text('Ali Raza'), findsNothing);
    expect(find.text('Sara Khan'), findsNothing);

    await openAddForm(t);
    await fillForm(t, name: 'Ali Raza', phone: '03001111111', address: 'House 5, Street 2, Sahiwal');
    await tapVisible(t, find.byType(FilledButton));
    // No duplicate warning for Owner Two: Owner One's customer with this number is invisible to them.
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add customer'));
    await pumpUntil(t, find.text('Ali Raza'));
    expect(find.textContaining('already exists'), findsNothing);
  });
}
