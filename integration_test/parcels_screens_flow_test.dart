// Parcels tab, list and details through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcels_screens_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:deliv_track/routes/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('owner sees parcels newest first, opens details, adds one from the list; another user cannot reach them', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Owner One', email: 'ps1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    final ali = Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final firstId = await parcels.create(ParcelInput(
      customer: ali,
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 11111',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));
    await parcels.create(ParcelInput(
      customer: ali,
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 1, unitPricePaisa: 0)],
      method: CollectionMethod.giftFree,
      service: PostalService.vpl,
      status: ParcelStatus.draft,
    ));

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: products,
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await pumpUntil(t, find.text('Welcome, Owner One'));

    // --- list
    await t.tap(_tab('Parcels'));
    await pumpUntil(t, find.text('ADT-000002'));
    final orders = t.widgetList<Text>(find.textContaining('ADT-')).map((w) => w.data).toList();
    expect(orders, ['ADT-000002', 'ADT-000001'], reason: 'newest first');
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('No postal reference yet'), findsOneWidget);
    expect(find.text('VPP · VPP 11111'), findsOneWidget);

    // --- details of the first parcel
    await t.tap(find.text('ADT-000001'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000001'));
    await t.pumpAndSettle();
    for (final text in ['2 pieces × Rs. 2,500 each = Rs. 5,000', 'VPP 11111', 'Rs. 150', 'Post office collection', 'Ali Raza']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    await t.pageBack();
    await pumpUntil(t, find.widgetWithText(AppBar, 'Parcels'));
    await t.pumpAndSettle();

    // --- add from the list: after saving the new parcel's details open
    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Parcel'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(TextFormField, 'Select a customer').first);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Select customer'));
    await t.pumpAndSettle();
    await pumpUntil(t, find.text('Ali Raza'));
    await t.tap(find.text('Ali Raza'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(ChoiceChip, 'Advance paid'));
    await t.pump();
    await tapVisible(t, find.widgetWithText(TextFormField, 'Select a product').first);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Select product'));
    await t.pumpAndSettle();
    await pumpUntil(t, find.text('Mango Box'));
    await t.tap(find.text('Mango Box'));
    await t.pumpAndSettle();
    await typeInto(t, find.widgetWithText(TextFormField, 'e.g. 2'), '3');
    await typeInto(t, find.widgetWithText(TextFormField, 'Agreed price'), '100');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000003'));
    await t.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Rs. 300'), findsWidgets);
    await t.pageBack();
    await pumpUntil(t, find.widgetWithText(AppBar, 'Parcels'));
    await t.pumpAndSettle();
    await pumpUntil(t, find.text('ADT-000003'));

    // --- a different user: empty list, and the first user's parcel cannot be opened by its address
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Owner Two', email: 'ps2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Owner Two'));
    await t.tap(_tab('Parcels'));
    await pumpUntil(t, find.text('No parcels yet'));
    expect(find.text('ADT-000001'), findsNothing);

    final router = GoRouter.of(t.element(find.byType(Scaffold).first));
    router.push(AppRoutes.parcelPath(firstId));
    // The app only ever reads inside the signed-in user's own data, so the address leads nowhere.
    await pumpUntil(t, find.text('This parcel was not found'));
    expect(find.text('Mango Box'), findsNothing, reason: "the other user's data must not appear");
    expect(find.text('Ali Raza'), findsNothing);
  });
}
