import 'package:deliv_track/features/customers/data/phone_dialer.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customer_details_screen.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/tab_finders.dart';

class _Dialer implements PhoneDialer {
  _Dialer({this.works = true});
  final bool works;
  final dialed = <String>[];
  @override
  Future<bool> dial(String phone) async {
    dialed.add(phone);
    return works;
  }
}

const _ali = Customer(
  id: 'c1',
  name: 'Ali Raza',
  phone: '+92 300 1111111',
  address: 'House 5, Street 2, Sahiwal',
);

// testParcel always belongs to customer "c1".
Parcel _p(
  String id,
  int seq, {
  String customerId = 'c1',
  int received = 0,
  CollectionMethod method = CollectionMethod.postalCollection,
  bool archived = false,
}) => testParcel(
  id: id,
  sequence: seq,
  customerId: customerId,
  received: received,
  method: method,
  isArchived: archived,
);

Future<({_Dialer dialer, List<Parcel> opened, List<Customer> edited})> _open(
  WidgetTester t,
  FakeParcelRepository parcels, {
  Size size = const Size(393, 1600),
  double scale = 1,
  _Dialer? dialer,
  String id = 'c1',
  List<Customer>? customers,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final d = dialer ?? _Dialer();
  final opened = <Parcel>[];
  final edited = <Customer>[];
  await t.pumpWidget(
    MaterialApp(
      home: CustomerDetailsScreen(
        customerRepository: FakeCustomerRepository(
          initial: customers ?? [_ali],
        ),
        parcelRepository: parcels,
        customerId: id,
        dialer: d,
        onEdit: (c) async {
          edited.add(c);
          return c.id;
        },
        onOpenParcel: opened.add,
      ),
    ),
  );
  await t.pump();
  await t.pump();
  await t.pump();
  return (dialer: d, opened: opened, edited: edited);
}

void main() {
  testWidgets(
    'shows the name, phone, address, totals and the parcel history newest first',
    (t) async {
      await _open(
        t,
        FakeParcelRepository(
          initial: [
            _p('a', 1), // owes 5,000
            _p(
              'b',
              2,
              received: 200000,
              method: CollectionMethod.payLater,
            ), // owes 3,000 (Pay Later)
            _p(
              'c',
              3,
              received: 300000,
              method: CollectionMethod.advance,
            ), // owes 2,000, advance 3,000
          ],
        ),
      );
      expect(find.text('Ali Raza'), findsWidgets);
      expect(find.text('+92 300 1111111'), findsOneWidget);
      expect(find.text('House 5, Street 2, Sahiwal'), findsOneWidget);
      expect(find.bySemanticsLabel('Parcels: 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Outstanding: Rs. 10,000'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Pay Later balance: Rs. 3,000'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Advance received: Rs. 3,000'),
        findsOneWidget,
      );
      final orders = t
          .widgetList<Text>(find.textContaining('ADT-'))
          .map((w) => w.data)
          .where((text) => !text!.contains('to collect'))
          .toList();
      expect(orders, ['ADT-000003', 'ADT-000002', 'ADT-000001']);
    },
  );

  testWidgets(
    "only this customer's parcels count; another customer's and archived ones are left out",
    (t) async {
      final repo = FakeParcelRepository(
        initial: [
          _p('a', 1),
          _p('b', 2, customerId: 'c2'),
          _p('z', 3, archived: true),
        ],
      );
      await _open(t, repo, id: 'c1');
      expect(find.bySemanticsLabel('Parcels: 1'), findsOneWidget);
      expect(find.text('ADT-000001'), findsOneWidget);
      expect(find.text('ADT-000002'), findsNothing);
      expect(find.text('ADT-000003'), findsNothing);
    },
  );

  testWidgets(
    'Pay Later reminders: this customer\'s open Pay Later parcels with their own dates (overdue flagged, none for paid or other types)',
    (t) async {
      await _open(
        t,
        FakeParcelRepository(
          initial: [
            testParcel(
              id: 'a',
              sequence: 1,
              method: CollectionMethod.payLater,
              payDate: '2000-01-01',
            ),
            testParcel(
              id: 'b',
              sequence: 2,
              method: CollectionMethod.payLater,
              payDate: '2999-01-01',
              received: 100000,
            ),
            testParcel(id: 'c', sequence: 3, method: CollectionMethod.payLater),
            testParcel(
              id: 'd',
              sequence: 4,
              method: CollectionMethod.payLater,
              received: 500000,
            ),
            testParcel(id: 'e', sequence: 5),
            testParcel(
              id: 'f',
              sequence: 6,
              customerId: 'c2',
              method: CollectionMethod.payLater,
              payDate: '2999-01-01',
            ),
          ],
        ),
      );
      expect(find.text('Pay Later reminders'), findsOneWidget);
      expect(find.text('ADT-000001 · Rs. 5,000 to collect'), findsOneWidget);
      expect(find.textContaining('Overdue by'), findsOneWidget);
      expect(find.text('ADT-000002 · Rs. 4,000 to collect'), findsOneWidget);
      expect(find.text('Due 1 Jan 2999'), findsOneWidget);
      expect(find.text('ADT-000003 · Rs. 5,000 to collect'), findsOneWidget);
      expect(find.text('No date set'), findsOneWidget);
      expect(find.textContaining('ADT-000004 ·'), findsNothing, reason: 'paid');
      expect(
        find.textContaining('ADT-000005 ·'),
        findsNothing,
        reason: 'not Pay Later',
      );
      expect(
        find.textContaining('ADT-000006 ·'),
        findsNothing,
        reason: "another customer's",
      );
    },
  );

  testWidgets(
    'no Pay Later section for a customer without open Pay Later parcels',
    (t) async {
      await _open(t, FakeParcelRepository(initial: [_p('a', 1)]));
      expect(find.text('Pay Later reminders'), findsNothing);
    },
  );

  testWidgets('a customer without parcels says so, with zero totals', (
    t,
  ) async {
    await _open(t, FakeParcelRepository());
    expect(find.text('No parcels for this customer yet.'), findsOneWidget);
    expect(find.bySemanticsLabel('Outstanding: Rs. 0'), findsOneWidget);
  });

  testWidgets('tapping the phone number dials it; a failure says so', (
    t,
  ) async {
    final env = await _open(t, FakeParcelRepository());
    await t.tap(find.text('+92 300 1111111'));
    await t.pump();
    expect(env.dialer.dialed, ['+92 300 1111111']);
    expect(find.text("Couldn't open the phone app."), findsNothing);

    final failing = _Dialer(works: false);
    await _open(t, FakeParcelRepository(), dialer: failing);
    await t.tap(find.text('+92 300 1111111'));
    await t.pump();
    await t.pump();
    expect(find.text("Couldn't open the phone app."), findsOneWidget);
  });

  testWidgets(
    'Edit opens the form for this customer and confirms when saved; a parcel row opens the parcel',
    (t) async {
      final env = await _open(t, FakeParcelRepository(initial: [_p('a', 1)]));
      await t.tap(find.byTooltip('Edit customer'));
      await t.pump();
      await t.pump();
      expect(env.edited.single.id, 'c1');
      expect(find.text('Customer updated.'), findsOneWidget);
      await t.tap(find.text('ADT-000001'));
      expect(env.opened.single.id, 'a');
    },
  );

  testWidgets('an unknown customer id shows a friendly message', (t) async {
    await _open(t, FakeParcelRepository(), id: 'nope');
    expect(find.text('This customer was not found'), findsOneWidget);
    expect(find.byTooltip('Edit customer'), findsNothing);
  });

  group('inside the app', () {
    testWidgets('Customers -> a customer -> a parcel -> back to the customer', (
      t,
    ) async {
      t.view.physicalSize = const Size(393, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        DelivTrackApp(
          repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
          productRepository: FakeProductRepository(),
          customerRepository: FakeCustomerRepository(initial: [_ali]),
          parcelRepository: FakeParcelRepository(initial: [_p('a', 1)]),
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      await t.tap(tabButton('Customers'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ali Raza'));
      await t.pumpAndSettle();
      expect(find.text('Parcel history'), findsOneWidget);
      await t.tap(find.text('ADT-000001'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'ADT-000001'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Parcel history'), findsOneWidget);
    });
  });

  group('copy the postal reference', () {
    testWidgets(
      'the copy button puts the reference on the clipboard and says so',
      (t) async {
        String? copied;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        t.view.physicalSize = const Size(393, 1600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          DelivTrackApp(
            repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
            productRepository: FakeProductRepository(),
            customerRepository: FakeCustomerRepository(initial: [_ali]),
            parcelRepository: FakeParcelRepository(
              initial: [testParcel(id: 'a', reference: 'VPP 12345')],
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 2000));
        await t.pumpAndSettle();
        await t.tap(tabButton('Parcels'));
        await t.pumpAndSettle();
        await t.tap(find.text('ADT-000001'));
        await t.pumpAndSettle();
        await t.ensureVisible(find.byTooltip('Copy tracking number'));
        await t.pump();
        await t.tap(find.byTooltip('Copy tracking number'));
        await t.pump();
        expect(copied, 'VPP 12345');
        expect(find.text('Tracking number copied.'), findsOneWidget);
      },
    );

    testWidgets('no copy button while the reference is empty', (t) async {
      t.view.physicalSize = const Size(393, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        DelivTrackApp(
          repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
          productRepository: FakeProductRepository(),
          customerRepository: FakeCustomerRepository(),
          parcelRepository: FakeParcelRepository(
            initial: [
              testParcel(
                id: 'a',
                status: ParcelStatus.draft,
                reference: '',
                charge: null,
              ),
            ],
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      await t.tap(tabButton('Parcels'));
      await t.pumpAndSettle();
      await t.tap(find.text('ADT-000001'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Copy tracking number'), findsNothing);
    });
  });

  group('responsive', () {
    for (final size in const [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(640, 300),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await _open(
            t,
            FakeParcelRepository(
              initial: [_p('a', 1), _p('b', 2, received: 100000)],
            ),
            size: size,
            scale: scale,
            customers: [
              const Customer(
                id: 'c1',
                name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman',
                phone: '+92 300 1111111',
                address: 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab',
              ),
            ],
          );
          expect(t.takeException(), isNull);
          await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
