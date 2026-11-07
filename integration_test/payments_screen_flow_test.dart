// Payments tab through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/payments_screen_flow_test.dart -d <android-emulator>
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

  testWidgets('owner sees totals and each list; receives from a row; another user sees nothing', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Payments One', email: 'pt1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final customer = Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final today = pakistanDate(DateTime.now().toUtc());
    Future<String> create(String reference, CollectionMethod method, {int quantity = 2, String? date, PostalService service = PostalService.vpp}) => parcels.create(ParcelInput(
          customer: customer,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: quantity, unitPricePaisa: 250000)],
          method: method,
          service: service,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        ));
    await create('VPP 11111', CollectionMethod.postalCollection); // 1: Pending, 5,000
    final partial = await create('VPP 22222', CollectionMethod.postalCollection); // 2: Partial
    final paid = await create('VPP 33333', CollectionMethod.postalCollection); // 3: Received
    final advance = await create('VPL 44444', CollectionMethod.advance, service: PostalService.vpl); // 4: Advance
    await create('VPL 55555', CollectionMethod.payLater, date: today, service: PostalService.vpl); // 5: Pay Later
    final returned = await create('VPP 66666', CollectionMethod.postalCollection); // 6: Review
    await create('VPL 77777', CollectionMethod.giftFree, service: PostalService.vpl); // 7: Gift (never listed)
    await parcels.recordPayment(partial, amountPaisa: 200000, type: PaymentType.customerPayment);
    await parcels.recordPayment(paid, amountPaisa: 500000, type: PaymentType.customerPayment);
    await parcels.recordPayment(advance, amountPaisa: 300000, type: PaymentType.advance);
    await parcels.markReturned(returned, date: today);

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Payments One'));
    await t.tap(_tab('Payments'));
    await pumpUntil(t, find.text('Outstanding'));
    await t.pumpAndSettle();
    // owed: #1 5,000 + #2 3,000 + #4 2,000 + #5 5,000 (the paid, returned and gift parcels are not counted)
    expect(find.text('Rs. 15,000'), findsOneWidget);
    expect(find.text('Rs. 5,000'), findsWidgets);
    expect(find.text('Advance received'), findsOneWidget);
    expect(find.text('Rs. 3,000'), findsWidgets);

    Future<void> pick(String label) async {
      await t.ensureVisible(find.widgetWithText(ChoiceChip, label));
      await t.pump();
      await t.tap(find.widgetWithText(ChoiceChip, label));
      await t.pumpAndSettle();
    }

    expect(find.text('ADT-000001'), findsOneWidget);
    expect(find.text('ADT-000005'), findsOneWidget, reason: 'Pay Later with nothing received is Pending too');
    await pick('Partially paid');
    expect(find.text('ADT-000002'), findsOneWidget);
    expect(find.text('ADT-000001'), findsNothing);
    await pick('Received');
    expect(find.text('ADT-000003'), findsOneWidget);
    await pick('Advance');
    expect(find.text('ADT-000004'), findsOneWidget);
    await pick('Pay Later');
    expect(find.text('ADT-000005'), findsOneWidget);
    await pick('Overdue');
    expect(find.text('Nothing in Overdue'), findsOneWidget, reason: 'due today is not overdue');
    await pick('Review');
    expect(find.text('ADT-000006'), findsOneWidget);
    expect(find.text('ADT-000007'), findsNothing);

    // --- receive from a row (the newest, ADT-000005, is first): it moves from Pending to Received
    await pick('Pending');
    await tapVisible(t, find.widgetWithText(TextButton, 'Receive').first);
    await pumpUntil(t, find.text('Mark payment received'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Customer payment'));
    await t.pump();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Confirm Payment'));
    await pumpUntil(t, find.text('Payment recorded.'));
    await pumpUntilGone(t, find.text('ADT-000005'));
    expect(find.text('ADT-000001'), findsOneWidget, reason: 'the other pending parcel is untouched');
    await pick('Received');
    expect(find.text('ADT-000005'), findsOneWidget);

    // --- another user: empty lists, zero totals
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Payments Two', email: 'pt2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Payments Two'));
    await t.tap(_tab('Payments'));
    await pumpUntil(t, find.text('Nothing in Pending'));
    expect(find.text('Rs. 0'), findsNWidgets(3));
  });
}
