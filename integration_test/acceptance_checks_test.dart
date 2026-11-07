// Two acceptance checks that need the real backend: AT-08 (product edits never change old parcels) and
// AT-27 (signing in again - as on another phone - brings back the same records).
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/acceptance_checks_test.dart -d <android-emulator>
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
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets('AT-08: renaming a product or changing its unit leaves old parcels exactly as they were', (t) async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuthRepository().signUp(name: 'AT Eight', email: 'at8${DateTime.now().microsecondsSinceEpoch}@codewingz.com', password: 'secret123');
    final products = FirestoreProductRepository();
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();

    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    final productId = (await products.watchAll().firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10))).single.id;
    final customerId = await customers.add(name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal');
    final parcelId = await parcels.create(ParcelInput(
      customer: Customer(id: customerId, name: 'Ali Raza', phone: '0300 1111111', address: 'House 5, Street 2, Sahiwal'),
      items: [ParcelItem.pieces(productId: productId, productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 11111',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));
    final before = (await parcels.watch(parcelId).first)!;

    await products.update(productId, name: 'Premium Mango Crate', saleUnit: SaleUnit.perKg);
    await customers.update(customerId, name: 'Ali Raza Khan', phone: '0300 1111111', address: 'A completely new address 9, Lahore');

    final after = (await parcels.watch(parcelId).first)!;
    expect(after.items.single.productName, 'Mango Box');
    expect(after.items.single.saleUnit, SaleUnit.perPiece);
    expect(after.items.single.quantity, 2);
    expect(after.items.single.unitPricePaisa, 250000);
    expect(after.expectedPaisa, before.expectedPaisa);
    expect(after.customerName, 'Ali Raza', reason: "the customer snapshot on the parcel is not rewritten either");
    expect(after.customerAddress, 'House 5, Street 2, Sahiwal');
  });

  testWidgets('AT-27: after signing out and signing in again (as on another phone) the same parcels and payments are there', (t) async {
    await FirebaseAuth.instance.signOut();
    final auth = FirebaseAuthRepository();
    final email = 'at27${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await auth.signUp(name: 'AT Twenty Seven', email: email, password: 'secret123');
    final parcels = FirestoreParcelRepository();
    final customerId = await FirestoreCustomerRepository().add(name: 'Sara Khan', phone: '0301 2222222', address: 'Flat 9, Block C, Multan');
    final parcelId = await parcels.create(ParcelInput(
      customer: Customer(id: customerId, name: 'Sara Khan', phone: '0301 2222222', address: 'Flat 9, Block C, Multan'),
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Honey Jar', quantity: 3, unitPricePaisa: 100000)],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 22222',
      deliveryChargePaisa: 15000,
      status: ParcelStatus.sent,
    ));
    await parcels.recordPayment(parcelId, amountPaisa: 100000, type: PaymentType.advance, note: 'first part');

    await auth.signOut();
    await auth.signIn(email: email, password: 'secret123');

    final back = (await FirestoreParcelRepository().watchAll().firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10))).single;
    expect(back.orderNumber, 'ADT-000001');
    expect(back.receivedPaisa, 100000);
    final payments = await FirestoreParcelRepository().watchPayments(parcelId).firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10));
    expect(payments.single.note, 'first part');
    expect((await FirestoreCustomerRepository().watchAll().firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10))).single.name, 'Sara Khan');
  });
}
