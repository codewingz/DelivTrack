import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customer_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_customer_repository.dart';

const _existing = Customer(id: 'c9', name: 'Ali Raza', phone: '0300 1234567', address: 'House 5, Sahiwal');

/// Opens the form from a button so the popped result (the saved id) can be observed.
class _Harness {
  String? result;
  bool popped = false;
}

Future<_Harness> _pump(WidgetTester t, FakeCustomerRepository repo,
    {Customer? customer, Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final harness = _Harness();
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              harness.result = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => CustomerFormScreen(repository: repo, customer: customer)),
              );
              harness.popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return harness;
}

Finder get _name => find.byType(TextFormField).at(0);
Finder get _phone => find.byType(TextFormField).at(1);
Finder get _address => find.byType(TextFormField).at(2);
Finder get _save => find.byType(FilledButton);

Future<void> _fill(WidgetTester t, {String name = 'Ali Raza', String phone = '03001234567', String address = 'House 5, Sahiwal'}) async {
  await t.enterText(_name, name);
  await t.enterText(_phone, phone);
  await t.enterText(_address, address);
}

Future<void> _tapSave(WidgetTester t) async {
  await t.ensureVisible(_save);
  await t.pump();
  await t.tap(_save);
}

void main() {
  group('add customer', () {
    testWidgets('is a full screen with three required fields', (t) async {
      await _pump(t, FakeCustomerRepository());
      expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Customer name *'), findsOneWidget);
      expect(find.text('Phone number *'), findsOneWidget);
      expect(find.text('Full address *'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('empty submit shows all three errors and saves nothing', (t) async {
      final repo = FakeCustomerRepository();
      await _pump(t, repo);
      await _tapSave(t);
      await t.pump();
      expect(find.text('Customer name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Full address is required'), findsOneWidget);
      expect(repo.adds, 0);
    });

    testWidgets('name: 1 character rejected, whitespace-only rejected, 2 accepted', (t) async {
      final repo = FakeCustomerRepository();
      await _pump(t, repo);
      await _fill(t, name: 'A');
      await _tapSave(t);
      await t.pump();
      expect(find.text('Use 2–60 characters'), findsOneWidget);

      await t.enterText(_name, '     ');
      await _tapSave(t);
      await t.pump();
      expect(find.text('Customer name is required'), findsOneWidget);
      expect(repo.adds, 0);

      await t.enterText(_name, ' Al ');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(repo.items.single.name, 'Al');
    });

    testWidgets('typing limits: name 60, phone 20, address 200', (t) async {
      await _pump(t, FakeCustomerRepository());
      await t.enterText(_name, 'x' * 90);
      await t.enterText(_phone, '1' * 40);
      await t.enterText(_address, 'y' * 300);
      expect(t.widget<TextFormField>(_name).controller!.text.length, 60);
      expect(t.widget<TextFormField>(_phone).controller!.text.length, 20);
      expect(t.widget<TextFormField>(_address).controller!.text.length, 200);
    });

    testWidgets('phone: letters are not accepted while typing', (t) async {
      await _pump(t, FakeCustomerRepository());
      await t.enterText(_phone, '0300abc1234567');
      expect(t.widget<TextFormField>(_phone).controller!.text, '03001234567');
    });

    for (final bad in ['12345', '0300123456', '030012345678', '++923001234567', '1234567890123456']) {
      testWidgets('phone "$bad" is rejected', (t) async {
        final repo = FakeCustomerRepository();
        await _pump(t, repo);
        await _fill(t, phone: bad);
        await _tapSave(t);
        await t.pump();
        expect(find.text('Enter a valid phone number'), findsOneWidget);
        expect(repo.adds, 0);
      });
    }

    for (final good in ['03001234567', '0300 1234567', '+92 300 1234567', '0411234567']) {
      testWidgets('phone "$good" is accepted and saved as typed', (t) async {
        final repo = FakeCustomerRepository();
        final h = await _pump(t, repo);
        await _fill(t, phone: good);
        await _tapSave(t);
        await t.pumpAndSettle();
        expect(repo.items.single.phone, good);
        expect(h.popped, isTrue);
      });
    }

    testWidgets('address: 4 characters rejected, 5 accepted', (t) async {
      final repo = FakeCustomerRepository();
      await _pump(t, repo);
      await _fill(t, address: 'abcd');
      await _tapSave(t);
      await t.pump();
      expect(find.text('Enter the full address (5–200 characters)'), findsOneWidget);
      expect(repo.adds, 0);
      await t.enterText(_address, 'abcde');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(repo.items.single.address, 'abcde');
    });

    testWidgets('valid save adds once and returns the new customer id to the caller', (t) async {
      final repo = FakeCustomerRepository();
      final h = await _pump(t, repo);
      await _fill(t);
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(repo.adds, 1);
      expect(h.popped, isTrue);
      expect(h.result, repo.items.single.id);
      expect(find.byType(CustomerFormScreen), findsNothing);
    });

    testWidgets('repeated taps while saving add only one customer', (t) async {
      final repo = FakeCustomerRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await _fill(t);
      await _tapSave(t);
      await t.pump();
      await t.tap(_save, warnIfMissed: false);
      await t.pump();
      expect(t.widget<FilledButton>(_save).onPressed, isNull);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(repo.adds, 1);
    });

    testWidgets('a failure shows the message, keeps the form and what was typed', (t) async {
      final repo = FakeCustomerRepository(failure: const AppFailure('No internet connection.'));
      final h = await _pump(t, repo);
      await _fill(t);
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(t.widget<TextFormField>(_name).controller!.text, 'Ali Raza');
      expect(h.popped, isFalse);
      expect(repo.adds, 0);
    });
  });

  group('duplicate phone warning', () {
    testWidgets('same number in another format: warns, Cancel keeps the form, Save anyway saves', (t) async {
      final repo = FakeCustomerRepository(initial: [_existing]);
      final h = await _pump(t, repo);
      await _fill(t, name: 'Sara Ali', phone: '+92 300 1234567');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(find.text('A customer with this number already exists: Ali Raza. Save anyway?'), findsOneWidget);

      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(repo.adds, 0);
      expect(h.popped, isFalse);
      expect(find.byType(CustomerFormScreen), findsOneWidget);

      await _tapSave(t);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Save anyway'));
      await t.pumpAndSettle();
      expect(repo.items.map((c) => c.name), containsAll(['Ali Raza', 'Sara Ali']));
      expect(h.popped, isTrue);
    });

    testWidgets('a different number saves without any warning', (t) async {
      final repo = FakeCustomerRepository(initial: [_existing]);
      await _pump(t, repo);
      await _fill(t, name: 'Sara Ali', phone: '03009999999');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(find.textContaining('already exists'), findsNothing);
      expect(repo.adds, 1);
    });
  });

  group('edit customer', () {
    testWidgets('prefilled; saving unchanged phone gives no duplicate warning; update keeps the id', (t) async {
      final repo = FakeCustomerRepository(initial: [_existing]);
      final h = await _pump(t, repo, customer: _existing);
      expect(find.widgetWithText(AppBar, 'Edit customer'), findsOneWidget);
      expect(t.widget<TextFormField>(_name).controller!.text, 'Ali Raza');
      expect(t.widget<TextFormField>(_phone).controller!.text, '0300 1234567');
      expect(t.widget<TextFormField>(_address).controller!.text, 'House 5, Sahiwal');

      await t.enterText(_address, 'New address 77, Lahore');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(find.textContaining('already exists'), findsNothing);
      expect(repo.updates, 1);
      expect(repo.adds, 0);
      expect(repo.items.single.address, 'New address 77, Lahore');
      expect(h.result, 'c9');
    });

    testWidgets('changing to a number another customer has shows the warning', (t) async {
      final other = const Customer(id: 'c2', name: 'Sara', phone: '03005555555', address: 'Other address 1');
      final repo = FakeCustomerRepository(initial: [_existing, other]);
      await _pump(t, repo, customer: _existing);
      await t.enterText(_phone, '0300-5555555');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(find.text('A customer with this number already exists: Sara. Save anyway?'), findsOneWidget);
    });
  });

  group('leaving the form', () {
    testWidgets('untouched form closes without asking', (t) async {
      final h = await _pump(t, FakeCustomerRepository());
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsNothing);
      expect(h.popped, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('typed text: back asks; Keep editing stays, Discard leaves', (t) async {
      final h = await _pump(t, FakeCustomerRepository());
      await t.enterText(_name, 'Ali');
      await t.pump(); // a frame passes between typing and tapping Back
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsOneWidget);
      expect(t.widget<TextFormField>(_name).controller!.text, 'Ali');

      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Discard'));
      await t.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsNothing);
      expect(h.popped, isTrue);
    });

    testWidgets('editing without changes closes without asking', (t) async {
      await _pump(t, FakeCustomerRepository(initial: [_existing]), customer: _existing);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsNothing);
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale with all errors visible', (t) async {
          await _pump(t, FakeCustomerRepository(failure: const AppFailure('No internet connection.')), size: size, scale: scale);
          expect(t.takeException(), isNull);
          await _tapSave(t);
          await t.pump();
          expect(t.takeException(), isNull);
          await _fill(t, name: 'Muhammad Afzaal Khan Niazi', phone: '+92 300 1234567', address: 'House 5, Street 12, Block C, Model Town, Sahiwal');
          await _tapSave(t);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(find.text('No internet connection.'), findsOneWidget);
        });
      }
    }
  });
}
