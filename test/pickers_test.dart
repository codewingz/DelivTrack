import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customer_picker_screen.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/views/product_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_product_repository.dart';

const _ali = Customer(
  id: 'c1',
  name: 'Ali Raza',
  phone: '03001111111',
  address: 'House 5, Sahiwal',
);
const _sara = Customer(
  id: 'c2',
  name: 'Sara Khan',
  phone: '0302-3333333',
  address: 'Shop 4, Lahore',
);

class _Result<T> {
  T? value;
  bool popped = false;
}

Future<_Result<T>> _open<T>(WidgetTester t, Widget Function() page) async {
  final result = _Result<T>();
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await Navigator.of(context)
                    .push<T>(MaterialPageRoute(builder: (_) => page()));
                result.popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return result;
}

void main() {
  group('CustomerPickerScreen', () {
    testWidgets('lists customers; tapping one returns it', (t) async {
      final repo = FakeCustomerRepository(initial: [_sara, _ali]);
      final result = await _open<Customer>(
        t,
        () => CustomerPickerScreen(repository: repo, onAdd: () async => null),
      );
      expect(find.widgetWithText(AppBar, 'Select customer'), findsOneWidget);
      final names = t
          .widgetList<ListTile>(find.byType(ListTile))
          .map((l) => (l.title as Text).data)
          .toList();
      expect(names, ['Ali Raza', 'Sara Khan']);
      await t.tap(find.text('Sara Khan'));
      await t.pumpAndSettle();
      expect(result.value?.id, 'c2');
    });

    testWidgets('search by name or phone', (t) async {
      final repo = FakeCustomerRepository(initial: [_sara, _ali]);
      await _open<Customer>(
        t,
        () => CustomerPickerScreen(repository: repo, onAdd: () async => null),
      );
      await t.enterText(find.byType(TextFormField).first, '+92 302');
      await t.pump();
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Ali Raza'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, 'nobody');
      await t.pump();
      expect(find.text('No customers match "nobody"'), findsOneWidget);
    });

    testWidgets(
      'New Customer: the saved customer is selected automatically and returned',
      (t) async {
        final repo = FakeCustomerRepository(initial: [_ali]);
        final result = await _open<Customer>(
          t,
          () => CustomerPickerScreen(
            repository: repo,
            onAdd: () async => repo.add(
              name: 'New Buyer',
              phone: '03004444444',
              address: 'Street 9, Multan',
            ),
          ),
        );
        await t.tap(find.widgetWithText(FloatingActionButton, 'New Customer'));
        await t.pumpAndSettle();
        expect(result.popped, isTrue);
        expect(result.value?.name, 'New Buyer');
      },
    );

    testWidgets(
      'leaving the New Customer form without saving stays on the picker',
      (t) async {
        final repo = FakeCustomerRepository(initial: [_ali]);
        final result = await _open<Customer>(
          t,
          () => CustomerPickerScreen(repository: repo, onAdd: () async => null),
        );
        await t.tap(find.widgetWithText(FloatingActionButton, 'New Customer'));
        await t.pumpAndSettle();
        expect(result.popped, isFalse);
        expect(find.widgetWithText(AppBar, 'Select customer'), findsOneWidget);
      },
    );

    testWidgets('empty account offers New Customer', (t) async {
      final repo = FakeCustomerRepository();
      var adds = 0;
      await _open<Customer>(
        t,
        () => CustomerPickerScreen(
          repository: repo,
          onAdd: () async {
            adds++;
            return null;
          },
        ),
      );
      expect(find.text('No customers yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'New Customer'));
      await t.pump();
      expect(adds, 1);
    });
  });

  group('ProductPickerScreen', () {
    const mango = Product(
      id: 'p1',
      name: 'Mango Box',
      saleUnit: SaleUnit.perPiece,
      isActive: true,
    );
    const fruits = Product(
      id: 'p2',
      name: 'Dry Fruits',
      saleUnit: SaleUnit.perKg,
      isActive: true,
    );
    const old = Product(
      id: 'p3',
      name: 'Old Stock',
      saleUnit: SaleUnit.perPiece,
      isActive: false,
    );

    testWidgets(
      'lists only active products with their unit; tapping returns one; there is no Add button',
      (t) async {
        final repo = FakeProductRepository(initial: [mango, fruits, old]);
        final result = await _open<Product>(
          t,
          () => ProductPickerScreen(repository: repo),
        );
        expect(find.text('Old Stock'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Per Kg'), findsOneWidget);
        await t.tap(find.text('Dry Fruits'));
        await t.pumpAndSettle();
        expect(result.value?.id, 'p2');
      },
    );

    testWidgets('search and empty states', (t) async {
      final repo = FakeProductRepository(initial: [mango, fruits]);
      await _open<Product>(t, () => ProductPickerScreen(repository: repo));
      await t.enterText(find.byType(TextFormField).first, 'mang');
      await t.pump();
      expect(find.text('Mango Box'), findsOneWidget);
      expect(find.text('Dry Fruits'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, 'zzz');
      await t.pump();
      expect(find.text('No products match "zzz"'), findsOneWidget);
    });

    testWidgets('no products points the user to the Products screen', (
      t,
    ) async {
      await _open<Product>(
        t,
        () => ProductPickerScreen(repository: FakeProductRepository()),
      );
      expect(find.text('No products to choose from'), findsOneWidget);
      expect(find.textContaining('More → Products'), findsOneWidget);
    });
  });
}
