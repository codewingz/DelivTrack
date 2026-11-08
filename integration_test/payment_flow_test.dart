// Receiving payments through the real UI + real Firestore (emulator).
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/payment_flow_test.dart -d <android-emulator>
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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('owner receives a partial and then the final payment from Parcel Details; another user sees nothing', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Payer One', email: 'pf1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    final id = await parcels.create(ParcelInput(
      customer: Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal'),
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 11111',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Payer One'));
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await pumpUntil(t, find.text('ADT-000001'));
    await t.tap(find.text('ADT-000001'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000001'));
    await t.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('No payments received yet'), findsOneWidget);

    Future<void> pay(String amount, String type) async {
      await tapVisible(t, find.widgetWithText(FilledButton, 'Mark Payment Received'));
      await pumpUntil(t, find.text('Mark payment received'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, type));
      await typeInto(t, find.byType(TextFormField).first, amount);
      await tapVisible(t, find.widgetWithText(FilledButton, 'Confirm Payment'));
    }

    // --- more than the order total is refused on screen, nothing recorded
    await pay('5000.01', 'Advance');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Cannot exceed outstanding Rs. 5,000'), findsOneWidget);
    await t.tapAt(const Offset(10, 60)); // dismiss the sheet by tapping the barrier
    await pumpUntilGone(t, find.text('Mark payment received'));
    expect(await parcels.watchPayments(id).first, isEmpty);

    // --- partial payment
    await pay('2000', 'Advance');
    await pumpUntil(t, find.text('Payment recorded.'));
    await pumpUntil(t, find.text('Partially paid'));
    expect(find.text('Rs. 3,000'), findsWidgets, reason: 'outstanding');
    expect(find.text('No payments received yet'), findsNothing);

    // --- final payment: parcel becomes Received and the button disappears
    await t.pumpAndSettle(const Duration(seconds: 5));
    await pay('3000', 'Post office remittance');
    await pumpUntil(t, find.text('Received'));
    await pumpUntilGone(t, find.widgetWithText(FilledButton, 'Mark Payment Received'));
    final history = await parcels.watchPayments(id).first;
    expect(history.map((p) => p.amountPaisa), [300000, 200000]);

    // --- another user: no parcels, and cannot read this user's payments
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle(); // let the first user's screens finish leaving
    await auth.signUp(name: 'Payer Two', email: 'pf2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Payer Two'));
    await expectLater(parcels.watchPayments(id).first, completion(isEmpty), reason: "scoped to the signed-in user's own data");
  });
}
