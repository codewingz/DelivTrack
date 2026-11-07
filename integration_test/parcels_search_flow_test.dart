// Search and filters on the Parcels tab through the real UI + real Firestore (emulator), two users.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcels_search_flow_test.dart -d <android-emulator>
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

  testWidgets('owner searches by order, reference, customer and product, filters, and uses the payment-date filter; another user finds nothing', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Searcher One', email: 'sr1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final aliId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final saraId = await customers.add(name: 'Sara Khan', phone: '0301 2222222', address: 'Flat 9, Block C, Multan');
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final sara = Customer(id: saraId, name: 'Sara Khan', phone: '0301 2222222', address: 'Flat 9, Block C, Multan');
    Future<String> create(Customer customer, String reference, String product, CollectionMethod method) => parcels.create(ParcelInput(
          customer: customer,
          items: [ParcelItem.pieces(productId: product, productName: product == 'p1' ? 'Mango Box' : 'Honey Jar', quantity: 2, unitPricePaisa: 250000)],
          method: method,
          service: PostalService.vpp,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          status: ParcelStatus.sent,
        ));
    final first = await create(ali, 'VPP 11111', 'p1', CollectionMethod.postalCollection);
    await create(sara, 'VPP 22222', 'p2', CollectionMethod.advance);
    await create(ali, 'VPP 33333', 'p2', CollectionMethod.postalCollection);
    await parcels.recordPayment(first, amountPaisa: 100000, type: PaymentType.customerPayment);
    final today = pakistanDate(DateTime.now().toUtc());

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Searcher One'));
    await t.tap(_tab('Parcels'));
    await pumpUntil(t, find.text('3 parcels'));
    await t.pumpAndSettle();

    Future<void> search(String text) async {
      await typeInto(t, find.byType(TextFormField).first, text);
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
    }

    await search('sara');
    expect(find.text('ADT-000002'), findsOneWidget);
    expect(find.text('1 match'), findsOneWidget);
    await search('VPP 33');
    expect(find.text('ADT-000003'), findsOneWidget);
    await search('adt-000001');
    expect(find.text('ADT-000001'), findsOneWidget);
    await search('0301');
    expect(find.text('ADT-000002'), findsOneWidget, reason: 'by phone number');
    await search('honey');
    expect(find.text('2 matches'), findsOneWidget, reason: 'by product');
    await search('nobody');
    expect(find.text('No parcels match'), findsOneWidget);
    await t.tap(find.text('Clear search and filters'));
    await t.pumpAndSettle();
    expect(find.text('3 parcels'), findsOneWidget);

    // --- filters: parcel type, then the payment-date range (queries the real payments)
    Future<void> openFilters() async {
      await tapVisible(t, find.widgetWithText(OutlinedButton, 'Filters'));
      await pumpUntil(t, find.text('Filter parcels'));
      await t.pumpAndSettle();
    }

    await openFilters();
    await t.tap(find.widgetWithText(FilterChip, 'Advance paid'));
    await t.pump();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Apply Filters'));
    await pumpUntil(t, find.text('1 match'));
    expect(find.text('ADT-000002'), findsOneWidget);
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();

    // Paid today: only the parcel that received a payment today. (Picking dates in the calendar is
    // covered by the widget tests; here the range is set on the view model through the sheet's today.)
    await openFilters();
    await tapVisible(t, find.widgetWithText(TextFormField, 'Any day').at(2));
    await pumpUntil(t, find.text('OK'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await tapVisible(t, find.widgetWithText(FilledButton, 'Apply Filters'));
    await pumpUntil(t, find.textContaining('Paid from'));
    await pumpUntil(t, find.text('1 match'));
    expect(find.text('ADT-000001'), findsOneWidget);
    expect(find.text('ADT-000003'), findsNothing);
    expect(today, isNotEmpty);

    // --- another user finds nothing
    await FirebaseAuth.instance.signOut();
    await pumpUntil(t, find.text('Welcome back'));
    await t.pumpAndSettle();
    await auth.signUp(name: 'Searcher Two', email: 'sr2${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    await pumpUntil(t, find.text('Welcome, Searcher Two'));
    await t.tap(_tab('Parcels'));
    await pumpUntil(t, find.text('No parcels yet'));
  });
}
