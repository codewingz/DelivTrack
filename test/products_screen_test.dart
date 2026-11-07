import 'dart:async';
import 'package:deliv_track/common_widgets/list_skeleton.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/views/product_form_sheet.dart';
import 'package:deliv_track/features/products/views/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_product_repository.dart';

Product _p(String id, String name, {bool active = true, SaleUnit unit = SaleUnit.perPiece}) =>
    Product(id: id, name: name, saleUnit: unit, isActive: active);

Future<void> _pump(WidgetTester t, FakeProductRepository repo, {Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(MaterialApp(home: ProductsScreen(repository: repo)));
  await t.pump();
  await t.pump();
}

Finder get _addFab => find.widgetWithText(FloatingActionButton, 'Add Product');
Finder get _sheet => find.byType(ProductFormSheet);
Finder get _sheetName => find.descendant(of: _sheet, matching: find.byType(TextFormField));
Finder _sheetButton(String label) => find.descendant(of: _sheet, matching: find.widgetWithText(FilledButton, label));
Finder get _search => find.byType(TextFormField).first;

Future<void> _openMenu(WidgetTester t, String productName, String item) async {
  await t.tap(find.byTooltip('Options for $productName'));
  await t.pumpAndSettle();
  await t.tap(find.text(item).last);
  await t.pumpAndSettle();
}

void main() {
  group('list states', () {
    testWidgets('shows a skeleton while loading, then the products sorted with their units', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango', unit: SaleUnit.perKg), _p('2', 'Apple')]);
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: ProductsScreen(repository: repo)));
      expect(find.byType(ListSkeleton), findsOneWidget);
      await t.pump();
      await t.pump();
      expect(find.byType(ListSkeleton), findsNothing);
      final names = t.widgetList<ListTile>(find.byType(ListTile)).map((l) => (l.title as Text).data).toList();
      expect(names, ['Apple', 'Mango']);
      expect(find.text('Per Kg'), findsOneWidget);
      expect(find.text('Per Piece'), findsOneWidget);
    });

    testWidgets('empty account shows guidance and an Add Product action that opens the sheet', (t) async {
      await _pump(t, FakeProductRepository());
      expect(find.text('No products yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
    });

    testWidgets('load error shows a message and Retry recovers', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango')]);
      await _pump(t, repo);
      repo.emitError(const AppFailure('No internet connection.'));
      await t.pump();
      await t.pump();
      expect(find.text("Couldn't load products"), findsOneWidget);
      expect(find.text('No internet connection.'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Retry'));
      await t.pump();
      await t.pump();
      expect(find.text('Mango'), findsOneWidget);
    });
  });

  group('search and segments', () {
    testWidgets('search narrows the list, shows a no-match message, and the clear button resets it', (t) async {
      await _pump(t, FakeProductRepository(initial: [_p('1', 'Raw Mango'), _p('2', 'Apple')]));
      expect(find.byTooltip('Clear'), findsNothing);

      await t.enterText(_search, 'mang');
      await t.pump();
      expect(find.text('Raw Mango'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.byTooltip('Clear'), findsOneWidget);

      await t.enterText(_search, 'zzz');
      await t.pump();
      expect(find.text('No products match "zzz"'), findsOneWidget);

      await t.tap(find.byTooltip('Clear'));
      await t.pump();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Raw Mango'), findsOneWidget);
      expect(find.byTooltip('Clear'), findsNothing);
    });

    testWidgets('Archived segment lists archived products; empty segments say so', (t) async {
      await _pump(t, FakeProductRepository(initial: [_p('1', 'Mango'), _p('2', 'Old Item', active: false)]));
      expect(find.text('Old Item'), findsNothing);
      await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await t.pump();
      expect(find.text('Old Item'), findsOneWidget);
      expect(find.text('Mango'), findsNothing);
    });

    testWidgets('no archived products shows a specific message', (t) async {
      await _pump(t, FakeProductRepository(initial: [_p('1', 'Mango')]));
      await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await t.pump();
      expect(find.text('No archived products'), findsOneWidget);
    });
  });

  group('add product', () {
    testWidgets('empty submit shows both field errors and does not call the repository', (t) async {
      final repo = FakeProductRepository();
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.tap(_sheetButton('Add Product'));
      await t.pump();
      expect(find.text('Product name is required'), findsOneWidget);
      expect(find.text('Choose how this product is sold'), findsOneWidget);
      expect(repo.adds, 0);
    });

    testWidgets('1-character name is rejected; padded 2-character name is accepted after trimming', (t) async {
      final repo = FakeProductRepository();
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, 'Per Piece'));
      await t.enterText(_sheetName, 'A');
      await t.tap(_sheetButton('Add Product'));
      await t.pump();
      expect(find.text('Use 2–60 characters'), findsOneWidget);
      expect(repo.adds, 0);

      await t.enterText(_sheetName, '   Ab   ');
      await t.tap(_sheetButton('Add Product'));
      await t.pumpAndSettle();
      expect(repo.items.single.name, 'Ab');
    });

    testWidgets('typing is limited to 60 characters', (t) async {
      await _pump(t, FakeProductRepository());
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'x' * 80);
      expect(t.widget<TextFormField>(_sheetName).controller!.text.length, 60);
    });

    testWidgets('valid add closes the sheet, shows a confirmation and lists the product', (t) async {
      final repo = FakeProductRepository();
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'Mango Box');
      await t.tap(find.widgetWithText(ChoiceChip, 'Per Kg'));
      await t.tap(_sheetButton('Add Product'));
      await t.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.text('Product added.'), findsOneWidget);
      expect(find.text('Mango Box'), findsOneWidget);
      expect(repo.items.single.saleUnit, SaleUnit.perKg);
    });

    testWidgets('duplicate name keeps the sheet open with an inline message', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango Box')]);
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'mango  BOX');
      await t.tap(find.widgetWithText(ChoiceChip, 'Per Piece'));
      await t.tap(_sheetButton('Add Product'));
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(find.text(duplicateProductMessage), findsOneWidget);
      expect(repo.items, hasLength(1));
    });

    testWidgets('connection failure shows the message and keeps what was typed', (t) async {
      final repo = FakeProductRepository(failure: const AppFailure('No internet connection.'));
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'Mango Box');
      await t.tap(find.widgetWithText(ChoiceChip, 'Per Piece'));
      await t.tap(_sheetButton('Add Product'));
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(t.widget<TextFormField>(_sheetName).controller!.text, 'Mango Box');
      expect(_sheet, findsOneWidget);
    });

    testWidgets('repeated taps while saving add only one product', (t) async {
      final repo = FakeProductRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await t.tap(_addFab);
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'Mango Box');
      await t.tap(find.widgetWithText(ChoiceChip, 'Per Piece'));
      await t.tap(_sheetButton('Add Product'));
      await t.pump();
      await t.tap(find.descendant(of: _sheet, matching: find.byType(FilledButton)), warnIfMissed: false);
      await t.pump();
      expect(repo.adds, 1);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(repo.items, hasLength(1));
    });
  });

  group('edit product', () {
    testWidgets('tapping a product opens the sheet prefilled; unit change shows the history note; save updates', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango', unit: SaleUnit.perPiece)]);
      await _pump(t, repo);
      await t.tap(find.text('Mango'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(_sheetName).controller!.text, 'Mango');
      expect(find.text('Existing parcels keep their old unit.'), findsNothing);

      await t.tap(find.widgetWithText(ChoiceChip, 'Per Kg'));
      await t.pump();
      expect(find.text('Existing parcels keep their old unit.'), findsOneWidget);

      await t.enterText(_sheetName, 'Raw Mango');
      await t.tap(_sheetButton('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('Product updated.'), findsOneWidget);
      expect(repo.items.single.name, 'Raw Mango');
      expect(repo.items.single.saleUnit, SaleUnit.perKg);
    });

    testWidgets('renaming onto another product shows the duplicate message', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango'), _p('2', 'Apple')]);
      await _pump(t, repo);
      await t.tap(find.text('Apple'));
      await t.pumpAndSettle();
      await t.enterText(_sheetName, 'mango');
      await t.tap(_sheetButton('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text(duplicateProductMessage), findsOneWidget);
      expect(repo.items.map((p) => p.name), containsAll(['Mango', 'Apple']));
    });
  });

  group('archive and restore', () {
    testWidgets('archive asks first: Cancel keeps it, Confirm moves it to Archived', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango')]);
      await _pump(t, repo);

      await _openMenu(t, 'Mango', 'Archive');
      expect(find.text('Archive "Mango"?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(repo.items.single.isActive, isTrue);

      await _openMenu(t, 'Mango', 'Archive');
      await t.tap(find.widgetWithText(TextButton, 'Archive'));
      await t.pumpAndSettle();
      expect(repo.items.single.isActive, isFalse);
      expect(find.text('"Mango" archived.'), findsOneWidget);
      expect(find.text('No active products'), findsOneWidget);
    });

    testWidgets('restore needs no confirmation', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Old', active: false)]);
      await _pump(t, repo);
      await t.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await t.pump();
      await _openMenu(t, 'Old', 'Restore');
      expect(repo.items.single.isActive, isTrue);
      expect(find.text('"Old" restored.'), findsOneWidget);
    });

    testWidgets('archive failure shows the error and changes nothing', (t) async {
      final repo = FakeProductRepository(initial: [_p('1', 'Mango')]);
      await _pump(t, repo);
      repo.failure = const AppFailure('No internet connection.');
      await _openMenu(t, 'Mango', 'Archive');
      await t.tap(find.widgetWithText(TextButton, 'Archive'));
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(repo.items.single.isActive, isTrue);
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    final longName = 'Extra Long Premium Mango Gift Box With Many Words ${'x' * 4}';
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('list, sheet, dialog and empty state do not overflow at $size text x$scale', (t) async {
          final repo = FakeProductRepository(initial: [_p('1', longName), _p('2', 'Apple', unit: SaleUnit.perKg)]);
          await _pump(t, repo, size: size, scale: scale);
          expect(t.takeException(), isNull);

          await t.dragUntilVisible(find.text(longName), find.byType(CustomScrollView), const Offset(0, -80));
          await t.pump();
          await t.tap(find.text(longName));
          await t.pumpAndSettle();
          expect(_sheet, findsOneWidget);
          expect(t.takeException(), isNull);
          await t.tap(_sheetButton('Save Changes'), warnIfMissed: false);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        });

        testWidgets('empty state and add sheet do not overflow at $size text x$scale', (t) async {
          await _pump(t, FakeProductRepository(), size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.ensureVisible(find.widgetWithText(FilledButton, 'Add Product'));
          await t.pump();
          await t.tap(find.widgetWithText(FilledButton, 'Add Product'));
          await t.pumpAndSettle();
          expect(_sheet, findsOneWidget);
          expect(t.takeException(), isNull);
          await t.ensureVisible(_sheetButton('Add Product'));
          await t.tap(_sheetButton('Add Product'));
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
