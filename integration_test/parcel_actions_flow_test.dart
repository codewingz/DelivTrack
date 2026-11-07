// Corrections, notes, Pay Later date and returns through the real UI + real Firestore (emulator).
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcel_actions_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('owner corrects a payment, adds notes, changes the Pay Later date and returns a parcel', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Actor One', email: 'pa1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final ali = Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final items = [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)];
    final collectionId = await parcels.create(ParcelInput(
      customer: ali,
      items: items,
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 11111',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));
    final laterId = await parcels.create(ParcelInput(
      customer: ali,
      items: items,
      method: CollectionMethod.payLater,
      service: PostalService.vpl,
      postalReference: 'VPL 22222',
      deliveryChargePaisa: 15000,
      estimatedPaymentDate: '2031-01-10',
      status: ParcelStatus.sent,
    ));
    await parcels.recordPayment(collectionId, amountPaisa: 200000, type: PaymentType.advance);

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Actor One'));
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await pumpUntil(t, find.text('ADT-000001'));

    Future<void> openParcel(String order) async {
      await t.tap(find.text(order));
      await pumpUntil(t, find.widgetWithText(AppBar, order));
      await t.pumpAndSettle();
    }

    Future<void> openSheet(Finder trigger, String title) async {
      await tapVisible(t, trigger);
      await pumpUntil(t, find.text(title));
      await t.pumpAndSettle();
    }

    // ---------- parcel 1: correct the payment, add notes, return it
    await openParcel('ADT-000001');
    await pumpUntil(t, find.text('Correct'));
    await openSheet(find.text('Correct'), 'Correct payment');
    await typeInto(t, find.byType(TextFormField).first, '3000');
    await typeInto(t, find.byType(TextFormField).last, 'Wrong amount entered');
    await tapVisible(t, find.widgetWithText(FilledButton, 'Save Correction'));
    await pumpUntil(t, find.text('Payment corrected.'));
    await pumpUntil(t, find.textContaining('Reversal'));
    await pumpUntilGone(t, find.text('Correct payment'));
    expect(find.textContaining('Corrected'), findsOneWidget);
    expect(find.text('Rs. 2,000 cancelled — Wrong amount entered'), findsOneWidget);
    var parcel = (await parcels.watch(collectionId).first)!;
    expect(parcel.receivedPaisa, 300000);
    expect(parcel.outstandingPaisa, 200000);

    await openSheet(find.widgetWithText(OutlinedButton, 'Add Notes'), 'Notes');
    await typeInto(t, find.byType(TextFormField).first, 'Call before delivery');
    await tapVisible(t, find.widgetWithText(FilledButton, 'Save Notes'));
    await pumpUntil(t, find.text('Notes saved.'));
    await pumpUntil(t, find.text('Call before delivery'));
    expect(find.widgetWithText(OutlinedButton, 'Edit Notes'), findsOneWidget);

    await openSheet(find.widgetWithText(OutlinedButton, 'Mark Returned'), 'Mark as returned');
    expect(find.textContaining('Nothing is refunded automatically'), findsOneWidget);
    await typeInto(t, find.byType(TextFormField).last, 'Customer refused');
    await tapVisible(t, find.widgetWithText(FilledButton, 'Mark Returned'));
    await pumpUntil(t, find.text('Parcel marked as returned.'));
    await pumpUntil(t, find.text('Requires payment review'));
    expect(find.text('Returned'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Mark Returned'), findsNothing);
    expect(find.text('Correct'), findsNothing, reason: "a returned parcel's payments are final");
    parcel = (await parcels.watch(collectionId).first)!;
    expect(parcel.status, ParcelStatus.returned);
    expect(parcel.paymentReviewRequired, isTrue);
    expect(parcel.returnReason, 'Customer refused');
    expect(parcel.outstandingPaisa, 200000, reason: 'nothing changes automatically');
    await t.pageBack();
    await pumpUntil(t, find.widgetWithText(AppBar, 'Parcels'));
    await t.pumpAndSettle();

    // ---------- parcel 2: Pay Later date
    await openParcel('ADT-000002');
    expect(find.text('10 Jan 2031'), findsOneWidget);
    await openSheet(find.widgetWithText(OutlinedButton, 'Change Pay Later Date'), 'Pay Later date');
    await t.tap(find.byTooltip('Clear date'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Clear Date'));
    await pumpUntil(t, find.text('Pay Later date saved.'));
    expect((await parcels.watch(laterId).first)!.estimatedPaymentDate, isNull);
    expect(find.text('Estimated payment date'), findsNothing);
  });
}
