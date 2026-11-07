// Add Parcel through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcel_form_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  Future<void> pickCustomer(WidgetTester t, String name) async {
    await tapVisible(t, field('Select a customer').first);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Select customer'));
    await t.pumpAndSettle();
    await pumpUntil(t, find.text(name));
    await t.tap(find.text(name));
    await t.pumpAndSettle();
  }

  Future<void> pickProduct(WidgetTester t, String name, {int row = 0}) async {
    await tapVisible(t, field('Select a product').at(row));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Select product'));
    await t.pumpAndSettle();
    await pumpUntil(t, find.text(name));
    await t.tap(find.text(name));
    await t.pumpAndSettle();
  }

  testWidgets('owner adds parcels through the form; a second user sees none of it', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Owner One', email: 'pf1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    await products.add(name: 'Dry Fruits', saleUnit: SaleUnit.perKg);

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: products,
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await pumpUntil(t, find.text('Welcome, Owner One'));
    final router = GoRouter.of(t.element(find.byType(Scaffold).first));

    // --- Parcel 1: post office collection, two products, slip details -> Sent, ADT-000001
    router.push(AppRoutes.parcelNew);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    expect(find.textContaining('assigned automatically when you save'), findsOneWidget);

    await tapVisible(t, find.byType(FilledButton));
    await t.pump();
    expect(find.text('Select a customer'), findsWidgets);
    expect(find.text('Select a parcel type'), findsOneWidget);

    await pickCustomer(t, 'Ali Raza');
    await tapVisible(t, find.widgetWithText(ChoiceChip, 'Post office collection'));
    await t.pump();
    await pickProduct(t, 'Mango Box');
    await typeInto(t, field('e.g. 2'), '2');
    await typeInto(t, field('Agreed price'), '2500');
    await tapVisible(t, find.text('Add another product'));
    await t.pump();
    await pickProduct(t, 'Dry Fruits', row: 1);
    await typeInto(t, field('e.g. 1.5'), '1.25');
    await typeInto(t, field('Agreed price').last, '800');
    expect(find.text('Products total: Rs. 6,000'), findsOneWidget);
    await typeInto(t, field('Enter VPP / VPL / VPR reference from slip'), 'vpp 12345');
    await typeInto(t, field('Amount on slip'), '150.50');
    await typeInto(t, field('Weight shown on slip'), '3.2');
    expect(find.text('Save & Mark Sent'), findsOneWidget);
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add parcel'));

    final first = (await parcels.watchAll().firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10))).single;
    expect(first.orderNumber, 'ADT-000001');
    expect(first.status, ParcelStatus.sent);
    expect(first.method, CollectionMethod.postalCollection);
    expect(first.service, PostalService.vpp);
    expect(first.postalReference, 'vpp 12345');
    expect(first.deliveryChargePaisa, 15050);
    expect(first.packedWeightGrams, 3200);
    expect(first.expectedPaisa, 600000);
    expect(first.outstandingPaisa, 600000);
    expect(first.paymentStatus, PaymentStatus.pending);
    expect(first.customerName, 'Ali Raza');
    expect(first.items.map((i) => i.productName), ['Mango Box', 'Dry Fruits']);
    expect(first.items.map((i) => i.lineTotalPaisa), [500000, 100000]);
    expect(first.sendingDate, pakistanDate(DateTime.now().toUtc()));

    // --- Parcel 2: the same reference typed differently is refused with the first order number
    router.push(AppRoutes.parcelNew);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    await pickCustomer(t, 'Ali Raza');
    await tapVisible(t, find.widgetWithText(ChoiceChip, 'Post office collection'));
    await t.pump();
    await pickProduct(t, 'Mango Box');
    await typeInto(t, field('e.g. 2'), '1');
    await typeInto(t, field('Agreed price'), '100');
    await typeInto(t, field('Enter VPP / VPL / VPR reference from slip'), 'VPP12345');
    await typeInto(t, field('Amount on slip'), '100');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntil(t, find.text('This postal reference is already used on ADT-000001.'));
    expect(find.widgetWithText(AppBar, 'Add parcel'), findsOneWidget, reason: 'the form stays open with its data');

    // a different reference then works and gets the next number
    await typeInto(t, field('Enter VPP / VPL / VPR reference from slip'), 'VPP 54321');
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add parcel'));
    final both = await parcels.watchAll().firstWhere((l) => l.length == 2).timeout(const Duration(seconds: 10));
    expect(both.map((p) => p.orderNumber), ['ADT-000002', 'ADT-000001']);

    // --- Parcel 3: Gift / Free draft (no slip yet) -> ADT-000003, nothing to collect
    router.push(AppRoutes.parcelNew);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    await pickCustomer(t, 'Ali Raza');
    await tapVisible(t, find.widgetWithText(ChoiceChip, 'Gift / Free'));
    await t.pump();
    await pickProduct(t, 'Mango Box');
    await typeInto(t, field('e.g. 2'), '3');
    expect(find.text('No payment expected (Gift / Free)'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);
    await tapVisible(t, find.byType(FilledButton));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add parcel'));
    final three = await parcels.watchAll().firstWhere((l) => l.length == 3).timeout(const Duration(seconds: 10));
    final gift = three.first;
    expect(gift.orderNumber, 'ADT-000003');
    expect(gift.status, ParcelStatus.draft);
    expect(gift.expectedPaisa, 0);
    expect(gift.paymentStatus, PaymentStatus.notRequired);
    expect(gift.service, PostalService.vpl);

    // --- Leaving a half-filled form asks first
    router.push(AppRoutes.parcelNew);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(ChoiceChip, 'Advance paid'));
    await t.pump();
    await t.pageBack();
    await pumpUntil(t, find.text('Discard this parcel?'));
    await t.tap(find.widgetWithText(TextButton, 'Discard'));
    await pumpUntilGone(t, find.widgetWithText(AppBar, 'Add parcel'));
    expect((await parcels.watchAll().first).length, 3, reason: 'nothing was created');

    // --- A second user starts clean: own numbering, none of the first user's customers/products
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Owner Two', email: 'pf2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Owner Two'));
    final router2 = GoRouter.of(t.element(find.byType(Scaffold).first));
    router2.push(AppRoutes.parcelNew);
    await pumpUntil(t, find.widgetWithText(AppBar, 'Add parcel'));
    await t.pumpAndSettle();
    await tapVisible(t, field('Select a customer').first);
    await pumpUntil(t, find.text('No customers yet'));
    expect(find.text('Ali Raza'), findsNothing);
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await tapVisible(t, field('Select a product').first);
    await pumpUntil(t, find.text('No products to choose from'));
    expect(find.text('Mango Box'), findsNothing);
    expect(await parcels.watchAll().first, isEmpty);
  });
}
