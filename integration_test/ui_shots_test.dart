// Takes screenshots of the real app (Android emulator + Firebase emulators) for visual review.
// Run via flutter drive; see AGENTS.md "Verification commands".
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/ui_shots_test.dart \
//     -d emulator-5554 --dart-define=SHOT_TAG=phone
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/views/product_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _tag = String.fromEnvironment('SHOT_TAG', defaultValue: 'shot');

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
    await t.pumpWidget(DelivTrackApp(repository: repo, productRepository: FirestoreProductRepository()));
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
}
