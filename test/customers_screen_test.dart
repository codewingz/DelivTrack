import 'package:deliv_track/common_widgets/list_skeleton.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_customer_repository.dart';

Customer _c(String id, String name, String phone, [String address = 'House 1, Sahiwal']) =>
    Customer(id: id, name: name, phone: phone, address: address);

class _Calls {
  int adds = 0;
  final edited = <String>[];
  String? addResult;
  String? editResult;
}

Future<_Calls> _pump(WidgetTester t, FakeCustomerRepository repo, {Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final calls = _Calls();
  await t.pumpWidget(MaterialApp(
    home: CustomersScreen(
      repository: repo,
      onAdd: () async {
        calls.adds++;
        return calls.addResult;
      },
      onEdit: (customer) async {
        calls.edited.add(customer.id);
        return calls.editResult;
      },
    ),
  ));
  await t.pump();
  await t.pump();
  return calls;
}

Finder get _search => find.byType(TextFormField).first;
Finder get _addFab => find.widgetWithText(FloatingActionButton, 'Add Customer');

void main() {
  group('list states', () {
    testWidgets('skeleton while loading, then customers sorted by name with phone and address', (t) async {
      final repo = FakeCustomerRepository(initial: [_c('1', 'Zara Khan', '03001111111', 'Street 9, Lahore'), _c('2', 'Ali Raza', '+92 301 2222222')]);
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: CustomersScreen(repository: repo, onAdd: () async => null, onEdit: (_) async => null)));
      expect(find.byType(ListSkeleton), findsOneWidget);
      await t.pump();
      await t.pump();
      expect(find.byType(ListSkeleton), findsNothing);
      final names = t.widgetList<ListTile>(find.byType(ListTile)).map((l) => (l.title as Text).data).toList();
      expect(names, ['Ali Raza', 'Zara Khan']);
      expect(find.textContaining('+92 301 2222222'), findsOneWidget);
      expect(find.textContaining('Street 9, Lahore'), findsOneWidget);
    });

    testWidgets('no customers: guidance and an Add Customer action', (t) async {
      final calls = await _pump(t, FakeCustomerRepository());
      expect(find.text('No customers yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Add Customer'));
      await t.pump();
      expect(calls.adds, 1);
    });

    testWidgets('load error shows a message; Retry recovers', (t) async {
      final repo = FakeCustomerRepository(initial: [_c('1', 'Ali Raza', '03001111111')]);
      await _pump(t, repo);
      repo.emitError(const AppFailure('No internet connection.'));
      await t.pump();
      await t.pump();
      expect(find.text("Couldn't load the list"), findsOneWidget);
      expect(find.text('No internet connection.'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Retry'));
      await t.pump();
      await t.pump();
      expect(find.text('Ali Raza'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('by name (anywhere) and by phone digits in any format; no-match message; clear resets', (t) async {
      await _pump(t, FakeCustomerRepository(initial: [_c('1', 'Muhammad Ali', '+92 300 1111111'), _c('2', 'Sara Khan', '0301-2222222')]));

      await t.enterText(_search, 'ali');
      await t.pump();
      expect(find.text('Muhammad Ali'), findsOneWidget);
      expect(find.text('Sara Khan'), findsNothing);

      await t.enterText(_search, '0301 222');
      await t.pump();
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Muhammad Ali'), findsNothing);

      await t.enterText(_search, '03001111111');
      await t.pump();
      expect(find.text('Muhammad Ali'), findsOneWidget);

      await t.enterText(_search, 'zzz');
      await t.pump();
      expect(find.text('No customers match "zzz"'), findsOneWidget);

      await t.tap(find.byTooltip('Clear'));
      await t.pump();
      expect(find.text('Muhammad Ali'), findsOneWidget);
      expect(find.text('Sara Khan'), findsOneWidget);
    });
  });

  group('add and edit callbacks', () {
    testWidgets('Add Customer opens the form; a saved result shows a confirmation, leaving without saving does not', (t) async {
      final calls = await _pump(t, FakeCustomerRepository(initial: [_c('1', 'Ali Raza', '03001111111')]));
      await t.tap(_addFab);
      await t.pump();
      await t.pump();
      expect(calls.adds, 1);
      expect(find.text('Customer added.'), findsNothing);

      calls.addResult = 'new-id';
      await t.tap(_addFab);
      await t.pump();
      await t.pump();
      expect(calls.adds, 2);
      expect(find.text('Customer added.'), findsOneWidget);
    });

    testWidgets('tapping a customer opens Edit with that customer; saved result shows a confirmation', (t) async {
      final calls = await _pump(t, FakeCustomerRepository(initial: [_c('1', 'Ali Raza', '03001111111'), _c('2', 'Sara Khan', '03002222222')]));
      await t.tap(find.text('Sara Khan'));
      await t.pump();
      expect(calls.edited, ['2']);
      expect(find.text('Customer updated.'), findsNothing);

      calls.editResult = '2';
      await t.tap(find.text('Ali Raza'));
      await t.pump();
      await t.pump();
      expect(calls.edited, ['2', '1']);
      expect(find.text('Customer updated.'), findsOneWidget);
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    final longName = 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman ${'x' * 5}';
    final longAddress = 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab ${'y' * 40}';
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('list, empty, and no-match states do not overflow at $size text x$scale', (t) async {
          await _pump(t, FakeCustomerRepository(initial: [_c('1', longName, '+92 300 1234567', longAddress), _c('2', 'Ali', '03001111111')]),
              size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.enterText(_search, 'no-such-customer');
          await t.pump();
          expect(t.takeException(), isNull);
        });

        testWidgets('empty account does not overflow at $size text x$scale', (t) async {
          await _pump(t, FakeCustomerRepository(), size: size, scale: scale);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
