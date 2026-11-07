// Pay Later reminders through the real UI + real Firestore (emulator).
// Overdue reminders cannot be created here: the rules refuse a date in the past, so a parcel only
// becomes overdue as time passes (covered by the unit and widget tests with a fixed clock).
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/reminders_flow_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
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

  testWidgets('the bell counts what is due; reminders can be paid, dated and are private to their owner', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Reminder One', email: 'rm1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final ali = Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final today = pakistanDate(DateTime.now().toUtc());
    Future<String> payLater(String reference, String? date) => parcels.create(ParcelInput(
          customer: ali,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
          method: CollectionMethod.payLater,
          service: PostalService.vpl,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        ));
    final dueId = await payLater('VPL 11111', today);
    await payLater('VPL 22222', '2999-01-01');
    final undatedId = await payLater('VPL 33333', null);
    // A different kind of parcel never appears.
    await parcels.create(ParcelInput(
      customer: ali,
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 1, unitPricePaisa: 100000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 44444',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Reminder One'));
    await pumpUntil(t, find.byTooltip('Reminders, 1 due'));
    await t.tap(find.byTooltip('Reminders, 1 due'));
    await pumpUntil(t, find.text('Due today (1)'));
    await t.pumpAndSettle();
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.text('No date set (1)'), findsOneWidget);
    expect(find.text('ADT-000004'), findsNothing, reason: 'a Post office collection parcel is not a Pay Later reminder');

    // --- receive the full payment of the parcel due today: it leaves the list
    await tapVisible(t, find.widgetWithText(TextButton, 'Mark Received').first);
    await pumpUntil(t, find.text('Mark payment received'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Customer payment'));
    await t.pump();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Confirm Payment'));
    await pumpUntil(t, find.text('Payment recorded.'));
    await pumpUntilGone(t, find.text('Due today (1)'));
    expect((await parcels.watch(dueId).first)!.outstandingPaisa, 0);

    // --- give the undated parcel a date (today): it moves to "Due today"
    await tapVisible(t, find.text('Set Date'));
    await pumpUntil(t, find.text('Pay Later date'));
    await t.pumpAndSettle();
    await t.tap(find.byType(TextFormField).first);
    await pumpUntil(t, find.text('OK'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Save Date'));
    await pumpUntil(t, find.text('Pay Later date saved.'));
    await pumpUntil(t, find.text('Due today (1)'));
    expect((await parcels.watch(undatedId).first)!.estimatedPaymentDate, today);

    // --- back home the bell follows
    await t.pageBack();
    await pumpUntil(t, find.byTooltip('Reminders, 1 due'));

    // --- another user has no reminders
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Reminder Two', email: 'rm2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Reminder Two'));
    expect(find.byTooltip('Reminders'), findsOneWidget, reason: 'no due count for a user without parcels');
    await t.tap(find.byTooltip('Reminders'));
    await pumpUntil(t, find.text('Nothing to follow up'));
  });
}
