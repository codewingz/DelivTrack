// Editing a parcel through the real UI + real Firestore (emulator).
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcel_edit_flow_test.dart -d <android-emulator>
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

  testWidgets('owner turns a draft into a sent parcel from Parcel Details; the saved data and the list update', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    final parcels = FirestoreParcelRepository();

    await auth.signUp(name: 'Editor One', email: 'pe1${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    final id = await parcels.create(ParcelInput(
      customer: Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal'),
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      status: ParcelStatus.draft,
    ));

    await t.pumpWidget(DelivTrackApp(repository: auth, productRepository: products, customerRepository: customers, parcelRepository: parcels));
    await pumpUntil(t, find.text('Welcome, Editor One'));
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await pumpUntil(t, find.text('ADT-000001'));
    await t.tap(find.text('ADT-000001'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000001'));
    await t.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);

    // --- open the edit form: prefilled
    await t.tap(find.byTooltip('Edit parcel'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Edit parcel'));
    await t.pumpAndSettle();
    expect(find.textContaining('ADT-000001 (cannot be changed)'), findsOneWidget);
    expect(find.text('Mango Box'), findsOneWidget);
    expect(find.text('Saving will mark this parcel as Sent.'), findsNothing);

    // --- add the slip details; the form says it will become Sent
    await typeInto(t, find.widgetWithText(TextFormField, 'Enter VPP / VPL / VPR reference from slip'), 'VPP 4455');
    await typeInto(t, find.widgetWithText(TextFormField, 'Amount on slip'), '150.50');
    await t.ensureVisible(find.text('Saving will mark this parcel as Sent.'));
    expect(find.text('Saving will mark this parcel as Sent.'), findsOneWidget);
    await tapVisible(t, find.widgetWithText(FilledButton, 'Save Changes'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000001'));
    await pumpUntil(t, find.text('Parcel updated.'));
    await pumpUntil(t, find.text('VPP 4455'));
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);

    // --- same parcel in Firestore: one document, same order number, now sent
    final saved = await parcels.watch(id).first;
    expect(saved!.orderNumber, 'ADT-000001');
    expect(saved.status, ParcelStatus.sent);
    expect(saved.postalReference, 'VPP 4455');
    expect(saved.deliveryChargePaisa, 15050);

    // --- editing again: clearing the reference of a Sent parcel is refused on screen
    await t.tap(find.byTooltip('Edit parcel'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'Edit parcel'));
    await t.pumpAndSettle();
    await typeInto(t, find.widgetWithText(TextFormField, 'Enter VPP / VPL / VPR reference from slip'), '');
    await tapVisible(t, find.widgetWithText(FilledButton, 'Save Changes'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.widgetWithText(AppBar, 'Edit parcel'), findsOneWidget);
    expect((await parcels.watch(id).first)!.postalReference, 'VPP 4455');

    // --- Discard leaves without saving
    await t.pageBack();
    await pumpUntil(t, find.text('Discard your changes?'));
    await t.tap(find.widgetWithText(TextButton, 'Discard'));
    await pumpUntil(t, find.widgetWithText(AppBar, 'ADT-000001'));
    expect((await parcels.watch(id).first)!.postalReference, 'VPP 4455');
  });
}
