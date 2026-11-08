// Full-app Products flow through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/products_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/views/product_form_sheet.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

Finder get _sheet => find.byType(ProductFormSheet);

/// Waits for the sheet to exist and finish sliding up (taps during the animation miss).
Future<void> _sheetOpen(WidgetTester t) async {
  await pumpUntil(t, _sheet);
  await t.pumpAndSettle();
}
Finder get _sheetName => find.descendant(of: _sheet, matching: find.byType(TextFormField));
Finder _sheetButton(String label) => find.descendant(of: _sheet, matching: find.widgetWithText(FilledButton, label));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  Future<void> openProducts(WidgetTester t) async {
    await t.tap(find.text('More').last);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Products'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Products'));
  }

  Future<void> addProduct(WidgetTester t, String name, String unitLabel) async {
    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Product'));
    await _sheetOpen(t);
    await t.tap(_sheetName);
    await t.pump(const Duration(milliseconds: 200));
    await t.enterText(_sheetName, name);
    await t.tap(find.widgetWithText(ChoiceChip, unitLabel));
    await t.pump();
    await t.tap(_sheetButton('Add Product'));
  }

  testWidgets('owner manages products through the UI; a second user sees none of them', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final products = FirestoreProductRepository();
    await auth.signUp(name: 'Owner One', email: 'one${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: FirestoreCustomerRepository(), parcelRepository: FirestoreParcelRepository()));
    await pumpUntil(t, find.text('Welcome, Owner One'));
    await openProducts(t);
    await pumpUntil(t, find.text('No products yet'));

    // Add: validation first, then a valid product.
    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Product'));
    await _sheetOpen(t);
    await t.tap(_sheetButton('Add Product'));
    await t.pump();
    expect(find.text('Product name is required'), findsOneWidget);
    expect(find.text('Choose how this product is sold'), findsOneWidget);
    await t.tap(_sheetName);
    await t.pump(const Duration(milliseconds: 200));
    await t.enterText(_sheetName, '  Mango   Box ');
    await t.tap(find.widgetWithText(ChoiceChip, 'Per Kg'));
    await t.pump();
    await t.tap(_sheetButton('Add Product'));
    await pumpUntilGone(t, _sheet);
    await pumpUntil(t, find.text('Mango Box'));
    expect(find.text('Per Kg'), findsWidgets);

    // Duplicate (different case/spacing) is refused with the sheet kept open.
    await addProduct(t, 'mango  BOX', 'Per Piece');
    await pumpUntil(t, find.text(duplicateProductMessage));
    expect(_sheet, findsOneWidget);
    await t.tapAt(const Offset(5, 5)); // dismiss the sheet
    await pumpUntilGone(t, _sheet);

    // Second product, then edit the first (rename + unit).
    await addProduct(t, 'Apple Crate', 'Per Piece');
    await pumpUntilGone(t, _sheet);
    await pumpUntil(t, find.text('Apple Crate'));
    await t.tap(find.text('Mango Box'));
    await _sheetOpen(t);
    await t.enterText(_sheetName, 'Raw Mango');
    await t.tap(find.widgetWithText(ChoiceChip, 'Per Piece'));
    await t.pump();
    await t.tap(_sheetButton('Save Changes'));
    await pumpUntilGone(t, _sheet);
    await pumpUntil(t, find.text('Raw Mango'));
    await pumpUntilGone(t, find.text('Mango Box'));

    // Search narrows the list.
    await t.enterText(find.byType(TextFormField).first, 'apple');
    await t.pump();
    expect(find.text('Apple Crate'), findsOneWidget);
    expect(find.text('Raw Mango'), findsNothing);
    await t.tap(find.byTooltip('Clear'));
    await t.pump();
    expect(find.text('Raw Mango'), findsOneWidget);

    // Archive with confirmation; it moves to the Archived segment.
    await t.tap(find.byTooltip('Options for Raw Mango'));
    await t.pumpAndSettle();
    await t.tap(find.text('Archive').last);
    await pumpUntil(t, find.text('Archive "Raw Mango"?'));
    await t.tap(find.widgetWithText(TextButton, 'Archive'));
    await pumpUntilGone(t, find.text('Raw Mango'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await pumpUntil(t, find.text('Raw Mango'));
    expect(find.text('Apple Crate'), findsNothing);

    // The archived name stays reserved.
    await t.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await t.pump();
    await addProduct(t, 'raw mango', 'Per Kg');
    await pumpUntil(t, find.text(duplicateProductMessage));
    await t.tapAt(const Offset(5, 5));
    await pumpUntilGone(t, _sheet);

    // Log out, then a different user: sees nothing of the first user's data.
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle(); // let the first user's screens finish leaving
    await auth.signUp(name: 'Owner Two', email: 'two${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Owner Two'));
    await openProducts(t);
    await pumpUntil(t, find.text('No products yet'));
    expect(find.text('Apple Crate'), findsNothing);
    expect(find.text('Raw Mango'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await t.pump();
    expect(find.text('Raw Mango'), findsNothing);

    // The second user can use the very same names for their own products.
    await t.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await t.pump();
    await addProduct(t, 'Raw Mango', 'Per Kg');
    await pumpUntilGone(t, _sheet);
    await pumpUntil(t, find.text('Raw Mango'));
    expect(find.text('Raw Mango'), findsOneWidget);
  });
}
