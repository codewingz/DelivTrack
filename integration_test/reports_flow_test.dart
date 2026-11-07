// Reports and the Dashboard through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/reports_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('the dashboard, Payments and the reports agree; every report opens; another user sees nothing', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Reporter One', email: 'rp1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final ali = Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final today = pakistanDate(DateTime.now().toUtc());
    Future<String> create(String reference, CollectionMethod method, {String? date}) => parcels.create(ParcelInput(
          customer: ali,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
          method: method,
          service: PostalService.vpp,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        ));
    await create('VPP 11111', CollectionMethod.postalCollection); // owes 5,000
    final partial = await create('VPP 22222', CollectionMethod.postalCollection); // owes 3,000
    await create('VPP 33333', CollectionMethod.payLater, date: today); // owes 5,000
    final returned = await create('VPP 44444', CollectionMethod.postalCollection);
    await create('VPP 55555', CollectionMethod.giftFree);
    await parcels.recordPayment(partial, amountPaisa: 200000, type: PaymentType.customerPayment);
    await parcels.recordPayment(returned, amountPaisa: 100000, type: PaymentType.advance);
    await parcels.markReturned(returned, date: today);

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Reporter One'));
    await pumpUntil(t, find.bySemanticsLabel('Total parcels: 5'));
    // Outstanding: 5,000 + 3,000 + 5,000 (the returned parcel's debt and the Gift parcel are not counted)
    expect(find.bySemanticsLabel('Total outstanding: Rs. 13,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Total received: Rs. 3,000'), findsOneWidget, reason: "the returned parcel's Rs. 1,000 is still received");
    expect(find.bySemanticsLabel('Need payment review: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Reminders due today: 1'), findsOneWidget);

    // --- a count card opens the matching filtered list
    await t.tap(find.bySemanticsLabel('Gift / Free: 1'));
    await pumpUntil(t, find.text('Type: Gift / Free'));
    await pumpUntil(t, find.text('ADT-000005'));
    expect(find.text('1 match'), findsOneWidget);
    await t.tap(_tab('Home'));
    await t.pumpAndSettle();

    // --- Payments screen shows the same outstanding
    await t.tap(_tab('Payments'));
    await pumpUntil(t, find.text('Pay Later balance'));
    await t.pumpAndSettle();
    expect(find.text('Rs. 13,000'), findsOneWidget);

    // --- the outstanding report: the same total (AT-24)
    await t.tap(_tab('More'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Reports'));
    await t.pumpAndSettle();
    await t.tap(find.text('Outstanding payments'));
    await pumpUntil(t, find.text('Total outstanding Rs. 13,000'));
    expect(find.text('3 parcels'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();

    // --- the payment history reads the real payments
    await t.tap(find.text('Payment received history'));
    await pumpUntil(t, find.text('Total received Rs. 3,000'));
    expect(find.text('2 payments'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();

    for (final (title, expectation) in [
      ('Returned parcels', '1 returned parcel'),
      ('Gift / Free parcels', 'Total delivery charges Rs. 150'),
      ('Pay Later balances', 'Total balance Rs. 5,000'),
      ('Product-wise parcels', '1 product'),
      ('Date-wise parcels', '1 day'),
    ]) {
      await tapVisible(t, find.text(title));
      await pumpUntil(t, find.text(expectation));
      await t.pageBack();
      await t.pumpAndSettle();
    }

    // --- another user: zeros
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Reporter Two', email: 'rp2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Reporter Two'));
    await pumpUntil(t, find.bySemanticsLabel('Total parcels: 0'));
    expect(find.bySemanticsLabel('Total outstanding: Rs. 0'), findsOneWidget);
  });
}
