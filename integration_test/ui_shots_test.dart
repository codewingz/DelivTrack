// Takes screenshots of the real app (Android emulator + Firebase emulators) for visual review.
// Run via flutter drive; see AGENTS.md "Verification commands".
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/ui_shots_test.dart \
//     -d emulator-5554 --dart-define=SHOT_TAG=phone
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/views/product_form_sheet.dart';
import 'package:deliv_track/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _tag = String.fromEnvironment('SHOT_TAG', defaultValue: 'shot');

/// Scrolls a button into view first (at large text a sheet is taller than the screen), then taps it.
Future<void> _tapButton(WidgetTester t, Finder button) async {
  await t.ensureVisible(button);
  await t.pump();
  await t.tap(button);
}

/// Scrolls the page down in small steps until [target] has been built (a lazily built list may not have
/// it yet, especially at large text), then brings it fully into view.
Future<void> _reveal(WidgetTester t, Finder target) async {
  // Down first; if it is not below, it is above (the page may already be scrolled to the end).
  for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
    await t.drag(find.byType(CustomScrollView).first, Offset(0, i < 30 ? -300 : 300));
    await t.pump();
  }
  await t.ensureVisible(target);
  await t.pump();
}

/// Scrolls a list row (by its text) into view, then taps it.
Future<void> _tapRow(WidgetTester t, String text) async {
  await _reveal(t, find.text(text));
  await t.tap(find.text(text));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  Future<void> shot(WidgetTester t, String name) async {
    await _settle(t);
    await binding.takeScreenshot('${_tag}_$name');
  }

  testWidgets('screenshots: auth + shell', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final repo = FirebaseAuthRepository();
    await t.pumpWidget(DelivTrackApp(repository: repo, productRepository: FirestoreProductRepository(), customerRepository: FirestoreCustomerRepository(), parcelRepository: FirestoreParcelRepository()));
    await _settle(t);
    await _settle(t);
    await shot(t, '01_login');

    await repo.signUp(
      name: 'Muhammad Afzaal',
      email: 'shots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    await shot(t, '02_dashboard');

    await t.tap(find.text('More').last);
    await shot(t, '03_more');

    await t.tap(find.text('Log out').first);
    await shot(t, '04_logout_dialog');
    await t.tap(find.text('Cancel'));
    await _settle(t);

    // Products
    await t.tap(find.widgetWithText(ListTile, 'Products'));
    await shot(t, '05_products_empty');

    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Product'));
    await shot(t, '06_add_sheet');
    await t.tap(find.descendant(of: find.byType(ProductFormSheet), matching: find.widgetWithText(FilledButton, 'Add Product')));
    await shot(t, '07_add_sheet_errors');
    await t.tapAt(const Offset(5, 5));
    await _settle(t);

    final products = FirestoreProductRepository();
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    await products.add(name: 'Premium Gift Hamper With Very Long Descriptive Name Test', saleUnit: SaleUnit.perKg);
    await products.add(name: 'Dry Fruits', saleUnit: SaleUnit.perKg);
    await products.add(name: 'Old Stock Item', saleUnit: SaleUnit.perPiece);
    final old = (await products.watchAll().firstWhere((l) => l.any((p) => p.name == 'Old Stock Item'))).firstWhere((p) => p.name == 'Old Stock Item');
    await products.setActive(old.id, false);
    await shot(t, '08_list');

    await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await shot(t, '09_archived');
    await t.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await _settle(t);

    await t.tap(find.text('Mango Box'));
    await _settle(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Per Kg'));
    await shot(t, '10_edit_sheet_unit_changed');
  });

  testWidgets('screenshots: customers', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final repo = FirebaseAuthRepository();
    await repo.signUp(
      name: 'Muhammad Afzaal',
      email: 'cshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    await t.pumpWidget(DelivTrackApp(
      repository: repo,
      productRepository: FirestoreProductRepository(),
      customerRepository: FirestoreCustomerRepository(),
      parcelRepository: FirestoreParcelRepository(),
    ));
    await _settle(t);
    await _settle(t);
    await shot(t, '11_home_with_customers_tab');

    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Customers')));
    await shot(t, '12_customers_empty');

    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
    await shot(t, '13_customer_form');
    await t.tap(find.byType(FilledButton));
    await shot(t, '14_customer_form_errors');

    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Ali Raza');
    await t.enterText(fields.at(1), '+92 300 1111111');
    await t.enterText(fields.at(2), 'House 5, Street 2, Sahiwal');
    await t.pump();
    await t.tap(find.byType(FilledButton));
    await shot(t, '15_after_save_with_snackbar');

    final customers = FirestoreCustomerRepository();
    await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab');
    await customers.add(name: 'Sara Khan', phone: '0302-3333333', address: 'Shop 4, Main Bazaar, Lahore');
    await customers.add(name: 'Bilal Traders', phone: '0411234567', address: 'Office 7, Commercial Area, Multan');
    await shot(t, '16_customers_list');

    await t.enterText(find.byType(TextFormField).first, 'khan');
    await shot(t, '17_customers_search');
    await t.tap(find.byTooltip('Clear'));
    await _settle(t);

    await _tapRow(t, 'Sara Khan');
    await shot(t, '18_customer_details');
    await t.tap(find.byTooltip('Edit customer'));
    await shot(t, '18b_customer_edit');
    await t.pageBack();
    await _settle(t);
    await t.pageBack();
    await _settle(t);

    await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
    await _settle(t);
    final form = find.byType(TextFormField);
    await t.enterText(form.at(0), 'Ali Brother');
    await t.enterText(form.at(1), '03001111111');
    await t.enterText(form.at(2), 'Another house 9, Sahiwal');
    await t.pump();
    await t.tap(find.byType(FilledButton));
    await shot(t, '19_duplicate_phone_dialog');
  });

  testWidgets('screenshots: parcel form', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'pshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final products = FirestoreProductRepository();
    await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town Extension, Sahiwal');
    await products.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    await products.add(name: 'Dry Fruits Premium Gift Hamper With A Long Name', saleUnit: SaleUnit.perKg);
    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: products,
      customerRepository: customers,
      parcelRepository: FirestoreParcelRepository(),
    ));
    await _settle(t);
    await _settle(t);
    GoRouter.of(t.element(find.byType(Scaffold).first)).push(AppRoutes.parcelNew);
    await _settle(t);
    final scroll = find.byType(SingleChildScrollView).first;
    Future<void> top() async {
      await t.drag(scroll, const Offset(0, 6000));
      await _settle(t);
    }

    Future<void> bottom() async {
      await t.drag(scroll, const Offset(0, -6000));
      await _settle(t);
    }

    await shot(t, '20_parcel_form_empty');
    await bottom();
    await shot(t, '21_parcel_form_bottom');
    await t.tap(find.byType(FilledButton));
    await top();
    await shot(t, '22_parcel_form_errors');

    await t.tap(find.widgetWithText(TextFormField, 'Select a customer').first);
    await shot(t, '23_customer_picker');
    await t.tap(find.text('Muhammad Afzaal Khan Niazi Son Of Abdul Rehman'));
    await _settle(t);

    await t.tap(find.widgetWithText(ChoiceChip, 'Pay Later'));
    await _settle(t);
    await t.tap(find.widgetWithText(TextFormField, 'Select a product').first);
    await shot(t, '24_product_picker');
    await t.tap(find.text('Mango Box'));
    await _settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'e.g. 2'), '3');
    await t.enterText(find.widgetWithText(TextFormField, 'Agreed price'), '2500.50');
    await t.pump();
    await t.ensureVisible(find.text('Add another product'));
    await t.tap(find.text('Add another product'));
    await _settle(t);
    await t.tap(find.widgetWithText(TextFormField, 'Select a product').at(1));
    await _settle(t);
    await t.tap(find.text('Dry Fruits Premium Gift Hamper With A Long Name'));
    await _settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'e.g. 1.5'), '1.25');
    await t.enterText(find.widgetWithText(TextFormField, 'Agreed price').last, '800');
    await t.pump();
    await top();
    await shot(t, '25_parcel_form_filled_top');
    await bottom();
    await shot(t, '26_parcel_form_pay_later_bottom');

    await t.tap(find.widgetWithText(TextFormField, 'Leave empty if the customer gave no date'));
    await shot(t, '27_date_picker');
    await t.tap(find.text('OK'));
    await _settle(t);

    await t.tap(find.widgetWithText(ChoiceChip, 'Other'));
    await _settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Enter VPP / VPL / VPR reference from slip'), 'ZZ 998877');
    await t.enterText(find.widgetWithText(TextFormField, 'Amount on slip'), '150');
    await t.pump();
    await bottom();
    await shot(t, '28_other_service_ready_to_send');
  });

  testWidgets('screenshots: parcels list and details', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'plshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();
    const address = 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab';
    final aliId = await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final longId = await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: address);
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final long = Customer(id: longId, name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: address);

    await parcels.create(ParcelInput(
      customer: ali,
      items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000),
        ParcelItem.weight(productId: 'p2', productName: 'Dry Fruits', weightGrams: 1250, unitPricePaisa: 80000),
      ],
      method: CollectionMethod.postalCollection,
      service: PostalService.vpp,
      postalReference: 'VPP 12345',
      deliveryChargePaisa: 15050,
      packedWeightGrams: 3200,
      status: ParcelStatus.sent,
    ));
    await parcels.create(ParcelInput(
      customer: long,
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Premium Gift Hamper With A Very Long Descriptive Name', quantity: 1, unitPricePaisa: 99900)],
      method: CollectionMethod.payLater,
      service: PostalService.other,
      otherServiceName: 'Fast Courier Service',
      postalReference: 'ZZ 998877 / 2026',
      deliveryChargePaisa: 20000,
      estimatedPaymentDate: '2030-12-25',
      status: ParcelStatus.sent,
    ));
    await parcels.create(ParcelInput(
      customer: ali,
      items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 3, unitPricePaisa: 0)],
      method: CollectionMethod.giftFree,
      service: PostalService.vpl,
      status: ParcelStatus.draft,
    ));

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await _settle(t);
    await _settle(t);
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await shot(t, '30_parcels_list');

    await _tapRow(t, 'ADT-000001');
    await shot(t, '31_details_top');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
    await shot(t, '32_details_bottom');
    await t.pageBack();
    await _settle(t);

    await _tapRow(t, 'ADT-000002');
    await shot(t, '33_details_pay_later_other_service');
    await t.pageBack();
    await _settle(t);

    await _tapRow(t, 'ADT-000003');
    await shot(t, '34_details_gift_draft');

    // --- edit the draft: prefilled, then slip details make it Sent
    await t.tap(find.byTooltip('Edit parcel'));
    await shot(t, '35_edit_draft_top');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await shot(t, '36_edit_draft_bottom');
    await t.enterText(find.widgetWithText(TextFormField, 'Enter VPP / VPL / VPR reference from slip'), 'VPL 55667');
    await t.pump();
    await t.enterText(find.widgetWithText(TextFormField, 'Amount on slip'), '120');
    await t.pump();
    await shot(t, '37_edit_draft_ready_to_send');
    await t.pageBack();
    await _settle(t);
    await t.tap(find.text('Discard'));
    await _settle(t);
    await t.pageBack();
    await _settle(t);
    await _tapRow(t, 'ADT-000001');
    await _settle(t);
    await t.tap(find.byTooltip('Edit parcel'));
    await shot(t, '38_edit_sent_top');

    // --- receive a payment
    await t.pageBack();
    await _settle(t);
    final receive = find.widgetWithText(FilledButton, 'Mark Payment Received');
    await t.ensureVisible(receive);
    await t.pump();
    await t.tap(receive);
    await shot(t, '39_payment_sheet');
    await _tapButton(t, find.widgetWithText(FilledButton, 'Confirm Payment'));
    await shot(t, '40_payment_sheet_errors');
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.enterText(find.byType(TextFormField).first, '2000');
    await t.enterText(find.byType(TextFormField).last, 'First part');
    await t.pump();
    await shot(t, '41_payment_sheet_filled');
    await _tapButton(t, find.widgetWithText(FilledButton, 'Confirm Payment'));
    await _settle(t);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
    await shot(t, '42_details_after_payment');

    // --- correct the payment
    await _settle(t);
    await _settle(t);
    await t.ensureVisible(find.text('Correct'));
    await t.pump();
    await t.tap(find.text('Correct'));
    await shot(t, '43_correct_sheet');
    await _tapButton(t, find.widgetWithText(FilledButton, 'Save Correction'));
    await shot(t, '44_correct_sheet_errors');
    await t.enterText(find.byType(TextFormField).first, '3000');
    await t.enterText(find.byType(TextFormField).last, 'Wrong amount entered');
    await t.pump();
    await _tapButton(t, find.widgetWithText(FilledButton, 'Save Correction'));
    await _settle(t);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
    await shot(t, '45_history_after_correction');

    // --- notes, then return
    final addNotes = find.widgetWithText(OutlinedButton, 'Add Notes');
    await t.ensureVisible(addNotes);
    await t.pump();
    await t.tap(addNotes);
    await shot(t, '46_notes_sheet');
    await t.enterText(find.byType(TextFormField).first, 'Call before delivery');
    await t.pump();
    await _tapButton(t, find.widgetWithText(FilledButton, 'Save Notes'));
    await _settle(t);
    final markReturned = find.widgetWithText(OutlinedButton, 'Mark Returned');
    await t.ensureVisible(markReturned);
    await t.pump();
    await t.tap(markReturned);
    await shot(t, '47_return_sheet');
    await t.enterText(find.byType(TextFormField).last, 'Customer refused');
    await t.pump();
    await _tapButton(t, find.widgetWithText(FilledButton, 'Mark Returned'));
    await _settle(t);
    await shot(t, '48_returned_top');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
    await shot(t, '49_returned_bottom');
    await t.pageBack();
    await _settle(t);

    // --- Pay Later parcel: date sheet and the late-payment toggle
    await _tapRow(t, 'ADT-000002');
    await _settle(t);
    final changeDate = find.widgetWithText(OutlinedButton, 'Change Pay Later Date');
    await t.ensureVisible(changeDate);
    await t.pump();
    await t.tap(changeDate);
    await shot(t, '50_pay_later_date_sheet');
    await t.tap(find.byTooltip('Clear date'));
    await shot(t, '51_pay_later_date_cleared');
    await _tapButton(t, find.widgetWithText(FilledButton, 'Clear Date'));
    await _settle(t);
    final receiveLate = find.widgetWithText(FilledButton, 'Mark Payment Received');
    await t.ensureVisible(receiveLate);
    await t.pump();
    await t.tap(receiveLate);
    await _settle(t);
    await t.tap(find.byType(Switch));
    await shot(t, '52_payment_sheet_entered_late');
  });

  testWidgets('screenshots: reminders', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'rmshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();
    const address = 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab';
    final aliId = await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final longId = await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: address);
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final long = Customer(id: longId, name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: address);
    final today = pakistanDate(DateTime.now().toUtc());
    Future<void> payLater(Customer customer, String reference, int quantity, String? date) => parcels.create(ParcelInput(
          customer: customer,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: quantity, unitPricePaisa: 250000)],
          method: CollectionMethod.payLater,
          service: PostalService.vpl,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        )).then((_) {});
    await payLater(ali, 'VPL 11111', 2, today);
    await payLater(long, 'VPL 22222', 1, today);
    await payLater(ali, 'VPL 33333', 3, '2030-12-25');
    await payLater(long, 'VPL 44444', 4, null);

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await _settle(t);
    await _settle(t);
    await shot(t, '60_home_with_bell_badge');
    await t.tap(find.byTooltip('Reminders, 2 due'));
    await shot(t, '61_reminders');
    await t.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await shot(t, '62_reminders_bottom');
    await t.tap(find.text('Set Date'));
    await shot(t, '63_set_date_sheet');
  });

  testWidgets('screenshots: payments', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'ptshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();
    final aliId = await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final longId = await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town, Sahiwal');
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final long = Customer(id: longId, name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town, Sahiwal');
    final today = pakistanDate(DateTime.now().toUtc());
    Future<String> create(Customer customer, String reference, CollectionMethod method, int quantity, {String? date}) => parcels.create(ParcelInput(
          customer: customer,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: quantity, unitPricePaisa: 250000)],
          method: method,
          service: PostalService.vpl,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        ));
    await create(ali, 'VPL 11111', CollectionMethod.postalCollection, 2);
    final part = await create(long, 'VPL 22222', CollectionMethod.postalCollection, 3);
    await create(ali, 'VPL 33333', CollectionMethod.payLater, 4, date: today);
    final adv = await create(long, 'VPL 44444', CollectionMethod.advance, 1);
    await parcels.recordPayment(part, amountPaisa: 400000, type: PaymentType.customerPayment);
    await parcels.recordPayment(adv, amountPaisa: 100000, type: PaymentType.advance);

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await _settle(t);
    await _settle(t);
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Payments')));
    await shot(t, '70_payments_pending');
    await t.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await shot(t, '71_payments_pending_bottom');
    await t.drag(find.byType(CustomScrollView), const Offset(0, 6000));
    await t.pump();
    await _reveal(t, find.widgetWithText(ChoiceChip, 'Partially paid'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Partially paid'));
    await shot(t, '72_payments_partial');
    await _reveal(t, find.widgetWithText(ChoiceChip, 'Overdue'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Overdue'));
    await shot(t, '73_payments_overdue_empty');
  });

  testWidgets('screenshots: search and filters', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'srshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();
    final aliId = await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final saraId = await customers.add(name: 'Sara Khan', phone: '0301 2222222', address: 'Flat 9, Block C, Multan');
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
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
    await create(ali, 'VPP 11111', 'p1', CollectionMethod.postalCollection);
    await create(sara, 'VPP 22222', 'p2', CollectionMethod.advance);
    await create(ali, 'VPP 33333', 'p2', CollectionMethod.postalCollection);

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await _settle(t);
    await _settle(t);
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await shot(t, '80_parcels_list_with_search');
    await t.enterText(find.byType(TextFormField).first, 'ali');
    await t.pump(const Duration(milliseconds: 400));
    await shot(t, '81_search_results');
    await t.tap(find.widgetWithText(OutlinedButton, 'Filters'));
    await shot(t, '82_filter_sheet');
    await _tapButton(t, find.widgetWithText(FilterChip, 'Post office collection'));
    await _tapButton(t, find.widgetWithText(FilterChip, 'Pending'));
    await t.pump();
    await shot(t, '83_filter_sheet_choices');
    await _tapButton(t, find.widgetWithText(FilledButton, 'Apply Filters'));
    await _settle(t);
    await shot(t, '84_filters_applied_with_chips');
    await t.enterText(find.byType(TextFormField).first, 'zzz');
    await t.pump(const Duration(milliseconds: 400));
    await shot(t, '85_no_matches');
  });

  testWidgets('screenshots: dashboard and reports', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final auth = FirebaseAuthRepository();
    await auth.signUp(
      name: 'Muhammad Afzaal',
      email: 'dbshots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    final customers = FirestoreCustomerRepository();
    final parcels = FirestoreParcelRepository();
    final aliId = await customers.add(name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final longId = await customers.add(name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town, Sahiwal');
    final ali = Customer(id: aliId, name: 'Ali Raza', phone: '+92 300 1111111', address: 'House 5, Street 2, Sahiwal');
    final long = Customer(id: longId, name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', phone: '0301 2222222', address: 'House 123, Street 45, Block C, Model Town, Sahiwal');
    final today = pakistanDate(DateTime.now().toUtc());
    Future<String> create(Customer customer, String reference, CollectionMethod method, int quantity, {String? date}) => parcels.create(ParcelInput(
          customer: customer,
          items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: quantity, unitPricePaisa: 250000)],
          method: method,
          service: PostalService.vpl,
          postalReference: reference,
          deliveryChargePaisa: 15000,
          estimatedPaymentDate: date,
          status: ParcelStatus.sent,
        ));
    await create(ali, 'VPL 11111', CollectionMethod.postalCollection, 2);
    final part = await create(long, 'VPL 22222', CollectionMethod.postalCollection, 3);
    await create(ali, 'VPL 33333', CollectionMethod.payLater, 4, date: today);
    final adv = await create(long, 'VPL 44444', CollectionMethod.advance, 1);
    final back = await create(ali, 'VPL 55555', CollectionMethod.postalCollection, 2);
    await create(long, 'VPL 66666', CollectionMethod.giftFree, 1);
    await parcels.recordPayment(part, amountPaisa: 400000, type: PaymentType.customerPayment);
    await parcels.recordPayment(adv, amountPaisa: 100000, type: PaymentType.advance);
    await parcels.recordPayment(back, amountPaisa: 100000, type: PaymentType.advance);
    await parcels.markReturned(back, date: today, reason: 'Customer refused');

    await t.pumpWidget(DelivTrackApp(
      repository: auth,
      productRepository: FirestoreProductRepository(),
      customerRepository: customers,
      parcelRepository: parcels,
    ));
    await _settle(t);
    await _settle(t);
    await shot(t, '90_dashboard_top');
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -6000));
    await shot(t, '91_dashboard_bottom');
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
    await _settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Reports'));
    await shot(t, '92_reports_list');
    await t.tap(find.text('Outstanding payments'));
    await shot(t, '93_report_outstanding');
    await t.pageBack();
    await _settle(t);
    await t.tap(find.text('Payment received history'));
    await shot(t, '94_report_payment_history');
    await t.pageBack();
    await _settle(t);
    await t.tap(find.text('Returned parcels'));
    await shot(t, '95_report_returned');
    await t.pageBack();
    await _settle(t);
    await t.pageBack();
    await _settle(t);

    // --- Settings
    await t.tap(find.widgetWithText(ListTile, 'Settings'));
    await shot(t, '96_settings');
    await t.pageBack();
    await _settle(t);

    // --- Customers: figures on each row, then a customer's details
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Customers')));
    await shot(t, '97_customers_with_figures');
    await _tapRow(t, 'Ali Raza');
    await shot(t, '98_customer_details');
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -6000));
    await shot(t, '99_customer_details_bottom');
    await t.pageBack();
    await _settle(t);

    // --- Archive: the action on a returned parcel, the banner, and the archived list
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Parcels')));
    await _settle(t);
    await _tapRow(t, 'ADT-000005');
    await _settle(t);
    final archive = find.widgetWithText(OutlinedButton, 'Archive Parcel');
    await t.ensureVisible(archive);
    await t.pump();
    await shot(t, '100_details_archive_action');
    await t.tap(archive);
    await shot(t, '101_archive_confirm');
    await _tapButton(t, find.widgetWithText(TextButton, 'Archive'));
    await _settle(t);
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 6000));
    await shot(t, '102_archived_banner');
    await t.pageBack();
    await _settle(t);
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
    await _settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Archived parcels'));
    await shot(t, '103_archived_list');
  });
}
