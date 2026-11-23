import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customers_screen.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/views/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
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

Widget _customers(
  FakeCustomerRepository repo,
  Future<String?> Function() onAdd,
) => CustomersScreen.choose(
  repository: repo,
  parcelRepository: FakeParcelRepository(),
  onAdd: onAdd,
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
  group('CustomersScreen.choose', () {
    testWidgets('lists customers; tapping one returns it', (t) async {
      final repo = FakeCustomerRepository(initial: [_sara, _ali]);
      final result = await _open<Customer>(
        t,
        () => _customers(repo, () async => null),
      );
      expect(find.widgetWithText(AppBar, 'Select customer'), findsOneWidget);
      expect(find.text('Total due'), findsNothing);
      expect(
        t.getTopLeft(find.text('Ali Raza')).dy,
        lessThan(t.getTopLeft(find.text('Sara Khan')).dy),
      );
      await t.tap(find.text('Sara Khan'));
      await t.pumpAndSettle();
      expect(result.value?.id, 'c2');
    });

    testWidgets('search by name or phone', (t) async {
      final repo = FakeCustomerRepository(initial: [_sara, _ali]);
      await _open<Customer>(t, () => _customers(repo, () async => null));
      await t.enterText(find.byType(TextFormField).first, '+92 302');
      await t.pump();
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Ali Raza'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, 'nobody');
      await t.pump();
      expect(find.text('No customers match "nobody"'), findsOneWidget);
    });

    testWidgets(
      'Add Customer: the saved customer is selected automatically and returned',
      (t) async {
        final repo = FakeCustomerRepository(initial: [_ali]);
        final result = await _open<Customer>(
          t,
          () => _customers(
            repo,
            () async => repo.add(
              name: 'New Buyer',
              phone: '03004444444',
              address: 'Street 9, Multan',
            ),
          ),
        );
        await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
        await t.pumpAndSettle();
        expect(result.popped, isTrue);
        expect(result.value?.name, 'New Buyer');
      },
    );

    testWidgets(
      'leaving the Add Customer form without saving stays on the list',
      (t) async {
        final repo = FakeCustomerRepository(initial: [_ali]);
        final result = await _open<Customer>(
          t,
          () => _customers(repo, () async => null),
        );
        await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
        await t.pumpAndSettle();
        expect(result.popped, isFalse);
        expect(find.widgetWithText(AppBar, 'Select customer'), findsOneWidget);
      },
    );

    testWidgets('empty account offers Add Customer', (t) async {
      final repo = FakeCustomerRepository();
      var adds = 0;
      await _open<Customer>(
        t,
        () => _customers(repo, () async {
          adds++;
          return null;
        }),
      );
      expect(find.text('No customers yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Add Customer'));
      await t.pump();
      expect(adds, 1);
    });
  });

  group('ProductsScreen.choose', () {
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
      'lists only active products with their unit, without Archive or the tabs; tapping returns one',
      (t) async {
        final repo = FakeProductRepository(initial: [mango, fruits, old]);
        final result = await _open<Product>(
          t,
          () => ProductsScreen.choose(repository: repo),
        );
        expect(find.text('Old Stock'), findsNothing);
        expect(find.text('Archive'), findsNothing);
        expect(find.textContaining('Archived'), findsNothing);
        expect(
          find.widgetWithText(FloatingActionButton, 'Add Product'),
          findsOneWidget,
        );
        expect(find.text('Per Kg'), findsOneWidget);
        await t.tap(find.text('Dry Fruits'));
        await t.pumpAndSettle();
        expect(result.value?.id, 'p2');
      },
    );

    testWidgets('search and empty states', (t) async {
      final repo = FakeProductRepository(initial: [mango, fruits]);
      await _open<Product>(t, () => ProductsScreen.choose(repository: repo));
      await t.enterText(find.byType(TextFormField).first, 'mang');
      await t.pump();
      expect(find.text('Mango Box'), findsOneWidget);
      expect(find.text('Dry Fruits'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, 'zzz');
      await t.pump();
      expect(find.text('No products match "zzz"'), findsOneWidget);
    });

    testWidgets('no products offers Add Product', (t) async {
      await _open<Product>(
        t,
        () => ProductsScreen.choose(repository: FakeProductRepository()),
      );
      expect(find.text('No products yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add Product'), findsOneWidget);
    });
  });
}
