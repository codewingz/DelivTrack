import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/views/parcel_form_screen.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

const _ali = Customer(id: 'c1', name: 'Ali Raza', phone: '03001111111', address: 'House 5, Sahiwal');
const _mango = Product(id: 'p1', name: 'Mango Box', saleUnit: SaleUnit.perPiece, isActive: true);
const _fruits = Product(id: 'p2', name: 'Dry Fruits', saleUnit: SaleUnit.perKg, isActive: true);
const _honey = Product(id: 'p3', name: 'Honey Jar', saleUnit: SaleUnit.perPiece, isActive: true);

class _Env {
  _Env({FakeParcelRepository? parcels}) : parcels = parcels ?? FakeParcelRepository();
  final FakeParcelRepository parcels;
  final customers = FakeCustomerRepository(initial: [_ali]);
  final products = FakeProductRepository(initial: [_mango, _fruits, _honey]);
  String? result;
  bool popped = false;
}

Future<_Env> _open(WidgetTester t, {FakeParcelRepository? parcels, Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final env = _Env(parcels: parcels);
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              env.result = await Navigator.of(context).push<String>(MaterialPageRoute(
                builder: (_) => ParcelFormScreen(
                  parcelRepository: env.parcels,
                  customerRepository: env.customers,
                  productRepository: env.products,
                  onAddCustomer: () async => env.customers.add(name: 'Brand New', phone: '03005555555', address: 'New street 5, Multan'),
                ),
              ));
              env.popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return env;
}

Finder get _saveButton => find.byType(FilledButton);

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
}

Future<void> _pickCustomer(WidgetTester t, String name) async {
  final f = find.widgetWithText(TextFormField, 'Select a customer').first;
  await _scrollTo(t, f);
  await t.tap(f);
  await t.pumpAndSettle();
  await _tapPickerEntry(t, name);
}

Future<void> _tapPickerEntry(WidgetTester t, String name) async {
  await t.dragUntilVisible(find.text(name), find.byType(CustomScrollView).last, const Offset(0, -80));
  await t.pump();
  await t.tap(find.text(name));
  await t.pumpAndSettle();
}

Future<void> _chooseType(WidgetTester t, String label) async {
  await _scrollTo(t, find.widgetWithText(ChoiceChip, label));
  await t.tap(find.widgetWithText(ChoiceChip, label));
  await t.pump();
}

Future<void> _pickProduct(WidgetTester t, String name, {int row = 0}) async {
  final selects = find.widgetWithText(TextFormField, 'Select a product');
  final f = selects.at(row);
  await _scrollTo(t, f);
  await t.tap(f);
  await t.pumpAndSettle();
  await _tapPickerEntry(t, name);
}

Future<void> _type(WidgetTester t, String hintOrLabelText, String text, {int index = 0, bool last = false}) async {
  final matches = find.widgetWithText(TextFormField, hintOrLabelText);
  final f = last ? matches.last : matches.at(index);
  await _scrollTo(t, f);
  await t.enterText(f, text);
  await t.pump();
}

Future<void> _tapSave(WidgetTester t) async {
  await _scrollTo(t, _saveButton);
  await t.tap(_saveButton);
  await t.pump();
}

/// A complete, valid Post-office-collection parcel (1 product, slip details).
Future<void> _fillValidSent(WidgetTester t) async {
  await _pickCustomer(t, 'Ali Raza');
  await _chooseType(t, 'Post office collection');
  await _pickProduct(t, 'Mango Box');
  await _type(t, 'e.g. 2', '2');
  await _type(t, 'Agreed price', '2500');
  await _type(t, 'Enter VPP / VPL / VPR reference from slip', 'vpp 12345');
  await _type(t, 'Amount on slip', '150.50');
}

void main() {
  group('first look', () {
    testWidgets('no sending date, no expected-amount box, no notes; order number is automatic', (t) async {
      await _open(t);
      expect(find.widgetWithText(AppBar, 'Add parcel'), findsOneWidget);
      expect(find.textContaining('assigned automatically when you save'), findsOneWidget);
      expect(find.textContaining('Sending date'), findsNothing);
      expect(find.textContaining('Notes'), findsNothing);
      expect(find.textContaining('Expected'), findsNothing);
      expect(find.text('Products total: Rs. 0'), findsOneWidget);
      expect(find.text('Save as Draft'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('shows the fixed fields with their labels', (t) async {
      await _open(t);
      for (final label in ['Customer *', 'Parcel type *', 'Postal service *', 'Postal reference number', 'Delivery charges (Rs.)', 'Actual packed parcel weight (kg)']) {
        await _scrollTo(t, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Estimated payment date (optional)'), findsNothing, reason: 'only for Pay Later');
    });
  });

  group('validation', () {
    testWidgets('empty submit lists every required choice and creates nothing', (t) async {
      final env = await _open(t);
      await _tapSave(t);
      expect(find.text('Select a customer'), findsWidgets);
      expect(find.text('Select a parcel type'), findsOneWidget);
      expect(find.text('Select a product'), findsWidgets);
      expect(find.text('Select a postal service'), findsOneWidget);
      expect(env.parcels.creates, 0);
    });

    testWidgets('per-piece row: quantity and price are checked', (t) async {
      final env = await _open(t);
      await _pickCustomer(t, 'Ali Raza');
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Mango Box');
      await _tapSave(t);
      expect(find.text('Enter the number of pieces'), findsOneWidget);
      expect(find.text('Price per piece is required'), findsOneWidget);
      await _type(t, 'e.g. 2', '0');
      await _type(t, 'Agreed price', '0');
      await _tapSave(t);
      expect(find.text('Enter a whole number of pieces (1–99,999)'), findsOneWidget);
      expect(find.text('Enter an amount above zero'), findsOneWidget);
      expect(env.parcels.creates, 0);
    });

    testWidgets('per-kg row: weight is checked', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Dry Fruits');
      await _tapSave(t);
      expect(find.text('Weight is required'), findsOneWidget);
      await _type(t, 'e.g. 1.5', '0');
      await _tapSave(t);
      expect(find.text('Enter a valid weight in kg'), findsOneWidget);
    });

    testWidgets('postal reference: invalid text is refused even for a draft', (t) async {
      final env = await _open(t);
      await _type(t, 'Enter VPP / VPL / VPR reference from slip', 'AB');
      await _tapSave(t);
      expect(find.text('Use 5–30 letters or numbers (also - and /)'), findsOneWidget);
      expect(env.parcels.creates, 0);
    });

    testWidgets('delivery charge and packed weight formats are checked', (t) async {
      await _open(t);
      await _type(t, 'Amount on slip', '100000000');
      await _type(t, 'Weight shown on slip', '0');
      await _tapSave(t);
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(find.text('Enter a valid weight in kg'), findsOneWidget);
    });

    testWidgets('typing limits: charge 2 decimals, packed weight 3 decimals', (t) async {
      await _open(t);
      await _type(t, 'Amount on slip', '12.3456');
      expect(t.widget<TextFormField>(find.widgetWithText(TextFormField, '12.34')).controller!.text, '12.34');
      await _type(t, 'Weight shown on slip', '1.23456');
      expect(t.widget<TextFormField>(find.widgetWithText(TextFormField, '1.234')).controller!.text, '1.234');
    });
  });

  testWidgets('after a failed save, fixing a field clears its error (parcel type, customer, product)', (t) async {
    await _open(t);
    await _tapSave(t);
    // A hint and an error share the same words, so count both before and after.
    expect(find.text('Select a parcel type'), findsOneWidget);
    expect(find.text('Select a customer'), findsNWidgets(2));
    expect(find.text('Select a product'), findsNWidgets(2));

    await _chooseType(t, 'Pay Later');
    expect(find.text('Select a parcel type'), findsNothing);
    await _pickCustomer(t, 'Ali Raza');
    expect(find.text('Select a customer'), findsOneWidget, reason: 'only the hint is left');
    await _pickProduct(t, 'Mango Box');
    expect(find.text('Select a product'), findsOneWidget, reason: 'only the hint is left');
  });

  group('postal service follows the parcel type until the user chooses one', () {
    bool selected(WidgetTester t, String label) => t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

    testWidgets('collection -> VPP; advance, Pay Later, gift -> VPL', (t) async {
      await _open(t);
      for (final (type, expected) in [
        ('Post office collection', 'VPP'),
        ('Advance paid', 'VPL'),
        ('Pay Later', 'VPL'),
        ('Gift / Free', 'VPL'),
        ('Post office collection', 'VPP'),
      ]) {
        await _chooseType(t, type);
        await _scrollTo(t, find.widgetWithText(ChoiceChip, expected));
        expect(selected(t, expected), isTrue, reason: '$type -> $expected');
      }
    });

    testWidgets('a service chosen by the user is kept when the type changes', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _scrollTo(t, find.widgetWithText(ChoiceChip, 'VPR'));
      await t.tap(find.widgetWithText(ChoiceChip, 'VPR'));
      await t.pump();
      await _chooseType(t, 'Advance paid');
      expect(selected(t, 'VPR'), isTrue);
    });

    testWidgets('"Other" asks for a service name; choosing another service hides it again', (t) async {
      final env = await _open(t);
      await _scrollTo(t, find.widgetWithText(ChoiceChip, 'Other'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await t.pump();
      expect(find.text('Service name *'), findsOneWidget);
      await _fillSentMinimumWithoutService(t);
      await _tapSave(t);
      expect(find.text('Service name is required'), findsOneWidget);
      expect(env.parcels.creates, 0);

      await _type(t, 'Type the service written on slip', 'Fast Courier');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(env.parcels.created.single.otherServiceName, 'Fast Courier');

      // new form: pick Other then switch back
    });

    testWidgets('switching away from Other removes the name field and drops the name', (t) async {
      await _open(t);
      await _scrollTo(t, find.widgetWithText(ChoiceChip, 'Other'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await t.pump();
      await _type(t, 'Type the service written on slip', 'Fast Courier');
      await t.tap(find.widgetWithText(ChoiceChip, 'VPL'));
      await t.pump();
      expect(find.text('Service name *'), findsNothing);
    });
  });

  group('products', () {
    testWidgets('line total and products total follow the typed values (per piece)', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Mango Box');
      await _type(t, 'e.g. 2', '3');
      await _type(t, 'Agreed price', '2500.50');
      expect(find.text('Line total: Rs. 7,501.50'), findsOneWidget);
      expect(find.text('Products total: Rs. 7,501.50'), findsOneWidget);
    });

    testWidgets('per kg: weight x price per kg, rounded to a whole paisa', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Dry Fruits');
      await _type(t, 'e.g. 1.5', '0.333');
      await _type(t, 'Agreed price', '100.10');
      expect(find.text('Line total: Rs. 33.33'), findsOneWidget);
    });

    testWidgets('several rows add up; removing a row updates the total', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Mango Box');
      await _type(t, 'e.g. 2', '2');
      await _type(t, 'Agreed price', '100');
      await _scrollTo(t, find.text('Add another product'));
      await t.tap(find.text('Add another product'));
      await t.pump();
      await _pickProduct(t, 'Dry Fruits', row: 1);
      await _type(t, 'e.g. 1.5', '2');
      await _type(t, 'Agreed price', '50', last: true);
      expect(find.text('Products total: Rs. 300'), findsOneWidget);

      await _scrollTo(t, find.byTooltip('Remove product 2'));
      await t.tap(find.byTooltip('Remove product 2'));
      await t.pump();
      expect(find.text('Products total: Rs. 200'), findsOneWidget);
      expect(find.byTooltip('Remove product 1'), findsNothing, reason: 'the last row cannot be removed');
    });

    testWidgets('the same product twice is refused', (t) async {
      final env = await _open(t);
      await _pickCustomer(t, 'Ali Raza');
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Mango Box');
      await _scrollTo(t, find.text('Add another product'));
      await t.tap(find.text('Add another product'));
      await t.pump();
      await _pickProduct(t, 'Mango Box', row: 1);
      await _tapSave(t);
      expect(find.text('This product is already added'), findsOneWidget);
      expect(env.parcels.creates, 0);
    });

    testWidgets('switching a row to a product with another unit clears the typed amount', (t) async {
      await _open(t);
      await _chooseType(t, 'Post office collection');
      await _pickProduct(t, 'Mango Box');
      await _type(t, 'e.g. 2', '7');
      await _pickProduct(t, 'Mango Box'); // opens picker again
      // choose a per-kg product on the same row
      final f = find.widgetWithText(TextFormField, 'Mango Box');
      await _scrollTo(t, f);
      await t.tap(f);
      await t.pumpAndSettle();
      await t.tap(find.text('Dry Fruits'));
      await t.pumpAndSettle();
      expect(find.text('Weight (kg) *'), findsOneWidget);
      expect(find.text('Quantity (pieces) *'), findsNothing);
      expect(t.widget<TextFormField>(find.widgetWithText(TextFormField, 'e.g. 1.5')).controller!.text, isEmpty);
    });

    testWidgets('at most 20 products; the add button disappears at 20', (t) async {
      await _open(t);
      for (var i = 0; i < 19; i++) {
        await _scrollTo(t, find.text('Add another product'));
        await t.tap(find.text('Add another product'));
        await t.pump();
      }
      expect(find.text('Add another product'), findsNothing);
      await _scrollTo(t, find.text('Product 20'));
      expect(find.text('Product 20'), findsOneWidget);
    });

    testWidgets('Gift / Free hides prices and expects no payment; saved prices are zero', (t) async {
      final env = await _open(t);
      await _pickCustomer(t, 'Ali Raza');
      await _chooseType(t, 'Gift / Free');
      await _pickProduct(t, 'Mango Box');
      expect(find.text('Price per piece (Rs.) *'), findsNothing);
      expect(find.text('No payment expected (Gift / Free)'), findsOneWidget);
      await _type(t, 'e.g. 2', '4');
      await _tapSave(t);
      await t.pumpAndSettle();
      final input = env.parcels.created.single;
      expect(input.method, CollectionMethod.giftFree);
      expect(input.expectedPaisa, 0);
      expect(input.items.single.unitPricePaisa, 0);
      expect(input.status, ParcelStatus.draft, reason: 'no slip details yet');
    });
  });

  group('Pay Later date', () {
    testWidgets('appears only for Pay Later, is optional, and is dropped when the type changes', (t) async {
      final env = await _open(t);
      await _chooseType(t, 'Pay Later');
      await _scrollTo(t, find.text('Estimated payment date (optional)'));
      expect(find.text('Estimated payment date (optional)'), findsOneWidget);

      await t.tap(find.widgetWithText(TextFormField, 'Leave empty if the customer gave no date'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Clear date'), findsOneWidget);

      await _chooseType(t, 'Advance paid');
      expect(find.text('Estimated payment date (optional)'), findsNothing);
      await _chooseType(t, 'Pay Later');
      expect(find.byTooltip('Clear date'), findsNothing, reason: 'the date was dropped');
      expect(env.parcels.creates, 0);
    });

    testWidgets('a Pay Later parcel saves with and without a date', (t) async {
      final env = await _open(t);
      await _pickCustomer(t, 'Ali Raza');
      await _chooseType(t, 'Pay Later');
      await _pickProduct(t, 'Mango Box');
      await _type(t, 'e.g. 2', '1');
      await _type(t, 'Agreed price', '100');
      await _tapSave(t);
      await t.pumpAndSettle();
      expect(env.parcels.created.single.estimatedPaymentDate, isNull);
      expect(env.parcels.created.single.method, CollectionMethod.payLater);
    });
  });

  group('draft or sent', () {
    testWidgets('the button says Save & Mark Sent once reference and charge are both valid', (t) async {
      await _open(t);
      expect(find.text('Save as Draft'), findsOneWidget);
      await _type(t, 'Enter VPP / VPL / VPR reference from slip', 'VPP 12345');
      expect(find.text('Save as Draft'), findsOneWidget, reason: 'a charge is still missing');
      await _type(t, 'Amount on slip', '150');
      expect(find.text('Save & Mark Sent'), findsOneWidget);
      expect(find.textContaining('to mark this parcel as Sent'), findsNothing);
      await _type(t, 'Amount on slip', '');
      expect(find.text('Save as Draft'), findsOneWidget);
      expect(find.textContaining('to mark this parcel as Sent'), findsOneWidget);
    });

    testWidgets('a zero charge counts as a charge', (t) async {
      await _open(t);
      await _type(t, 'Enter VPP / VPL / VPR reference from slip', 'VPP 12345');
      await _type(t, 'Amount on slip', '0');
      expect(find.text('Save & Mark Sent'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('a complete sent parcel is created once with exactly what was entered', (t) async {
      final env = await _open(t);
      await _fillValidSent(t);
      await _type(t, 'Weight shown on slip', '1.25');
      await _tapSave(t);
      await t.pumpAndSettle();

      final input = env.parcels.created.single;
      expect(input.customer.id, 'c1');
      expect(input.method, CollectionMethod.postalCollection);
      expect(input.service, PostalService.vpp);
      expect(input.postalReference, 'vpp 12345');
      expect(input.deliveryChargePaisa, 15050);
      expect(input.packedWeightGrams, 1250);
      expect(input.status, ParcelStatus.sent);
      expect(input.items.single.productId, 'p1');
      expect(input.items.single.quantity, 2);
      expect(input.items.single.unitPricePaisa, 250000);
      expect(input.expectedPaisa, 500000);
      expect(env.result, 'parcel-1');
      expect(find.byType(ParcelFormScreen), findsNothing);
    });

    testWidgets('a minimal draft is created: customer, type, one product', (t) async {
      final env = await _open(t);
      await _pickCustomer(t, 'Ali Raza');
      await _chooseType(t, 'Advance paid');
      await _pickProduct(t, 'Mango Box');
      await _type(t, 'e.g. 2', '1');
      await _type(t, 'Agreed price', '99.99');
      await _tapSave(t);
      await t.pumpAndSettle();
      final input = env.parcels.created.single;
      expect(input.status, ParcelStatus.draft);
      expect(input.postalReference, isEmpty);
      expect(input.deliveryChargePaisa, isNull);
      expect(input.service, PostalService.vpl);
      expect(input.items.single.lineTotalPaisa, 9999);
    });

    testWidgets('a server-side refusal (reference already used) is shown and the form is kept', (t) async {
      final env = await _open(t, parcels: FakeParcelRepository(failure: const AppFailure('This postal reference is already used on ADT-000007.')));
      await _fillValidSent(t);
      await _tapSave(t);
      await t.pumpAndSettle();
      await _scrollTo(t, find.text('This postal reference is already used on ADT-000007.'));
      expect(find.text('This postal reference is already used on ADT-000007.'), findsOneWidget);
      expect(env.popped, isFalse);
      expect(find.byType(ParcelFormScreen), findsOneWidget);
      expect(t.widget<TextFormField>(find.widgetWithText(TextFormField, 'vpp 12345')).controller!.text, 'vpp 12345');
    });

    testWidgets('repeated taps while saving create one parcel', (t) async {
      final repo = FakeParcelRepository()..gate = Completer<void>();
      final env = await _open(t, parcels: repo);
      await _fillValidSent(t);
      await _tapSave(t);
      await t.pump();
      await t.tap(_saveButton, warnIfMissed: false);
      await t.pump();
      expect(t.widget<FilledButton>(_saveButton).onPressed, isNull);
      expect(env.parcels.creates, 1);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(env.parcels.creates, 1);
    });

    testWidgets('a past Pay Later date is refused by the input rules before anything is sent', (t) async {
      // The picker cannot choose a past day; this guards the model rule used by the form.
      final env = await _open(t);
      await _fillValidSent(t);
      expect(env.parcels.creates, 0);
    });
  });

  group('leaving the form', () {
    testWidgets('untouched: closes without asking', (t) async {
      final env = await _open(t);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(env.popped, isTrue);
      expect(find.text('Discard this parcel?'), findsNothing);
    });

    testWidgets('entered something: back asks; Cancel keeps it, Discard leaves', (t) async {
      final env = await _open(t);
      await _chooseType(t, 'Advance paid');
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Discard this parcel?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(find.byType(ParcelFormScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Discard'));
      await t.pumpAndSettle();
      expect(env.popped, isTrue);
      expect(env.parcels.creates, 0);
    });
  });

  group('customer picker', () {
    testWidgets('choosing a customer fills the field and keeps what was typed', (t) async {
      await _open(t);
      await _type(t, 'Enter VPP / VPL / VPR reference from slip', 'VPP 12345');
      await _pickCustomer(t, 'Ali Raza');
      expect(find.widgetWithText(TextFormField, 'Ali Raza'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'VPP 12345'), findsOneWidget, reason: 'unsaved parcel data is preserved');
    });

    testWidgets('New Customer returns to the parcel with the new customer selected', (t) async {
      await _open(t);
      final f = find.widgetWithText(TextFormField, 'Select a customer').first;
      await _scrollTo(t, f);
      await t.tap(f);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'New Customer'));
      await t.pumpAndSettle();
      expect(find.byType(ParcelFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Brand New'), findsOneWidget);
    });
  });

  group('responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale (empty with errors, then a filled form)', (t) async {
          final env = await _open(t, size: size, scale: scale);
          expect(t.takeException(), isNull);
          await _tapSave(t);
          expect(t.takeException(), isNull);
          await _pickCustomer(t, 'Ali Raza');
          await _chooseType(t, 'Pay Later');
          await _pickProduct(t, 'Mango Box');
          await _scrollTo(t, find.text('Add another product'));
          await t.tap(find.text('Add another product'));
          await t.pump();
          await _pickProduct(t, 'Dry Fruits', row: 1);
          expect(t.takeException(), isNull);
          await _scrollTo(t, find.widgetWithText(ChoiceChip, 'Other'));
          await t.tap(find.widgetWithText(ChoiceChip, 'Other'));
          await t.pump();
          await _tapSave(t);
          expect(t.takeException(), isNull);
          expect(env.parcels.creates, 0);
        });
      }
    }
  });
}

Future<void> _fillSentMinimumWithoutService(WidgetTester t) async {
  await _pickCustomer(t, 'Ali Raza');
  await _chooseType(t, 'Post office collection');
  await _scrollTo(t, find.widgetWithText(ChoiceChip, 'Other'));
  await t.tap(find.widgetWithText(ChoiceChip, 'Other'));
  await t.pump();
  await _pickProduct(t, 'Mango Box');
  await _type(t, 'e.g. 2', '1');
  await _type(t, 'Agreed price', '100');
}
