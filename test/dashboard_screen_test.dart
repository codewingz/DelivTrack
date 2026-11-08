import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/dashboard/views/dashboard_screen.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_search.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/greeting_finders.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/fake_reminder_scheduler.dart';
import 'helpers/tab_finders.dart';

class _Taps {
  final lists = <ParcelFilters>[];
  int payments = 0;
  int reminders = 0;
  int adds = 0;
  final opened = <String>[];
}

Future<_Taps> _pump(
  WidgetTester t,
  FakeParcelRepository repo, {
  Size size = const Size(393, 1800),
  double scale = 1,
  Clock? clock,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final taps = _Taps();
  await t.pumpWidget(
    MaterialApp(
      home: DashboardScreen(
        repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
        parcelRepository: repo,
        reminderScheduler: FakeReminderScheduler(),
        onOpenReminders: () => taps.reminders++,
        onOpenParcel: taps.opened.add,
        onOpenParcels: taps.lists.add,
        onOpenPayments: () => taps.payments++,
        onAddParcel: () => taps.adds++,
        clock: clock ?? const Clock(),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return taps;
}

Finder _card(String label) => find.bySemanticsLabel(RegExp('^$label: '));

ParcelInput _input() => ParcelInput(
  customer: const Customer(
    id: 'c1',
    name: 'Ali Raza',
    phone: '03001111111',
    address: 'House 5, Sahiwal',
  ),
  items: [
    ParcelItem.pieces(
      productId: 'p',
      productName: 'Mango Box',
      quantity: 1,
      unitPricePaisa: 100000,
    ),
  ],
  method: CollectionMethod.postalCollection,
  service: PostalService.vpp,
  postalReference: 'VPP 99999',
  deliveryChargePaisa: 15000,
  status: ParcelStatus.sent,
);

void main() {
  FakeParcelRepository repo() => FakeParcelRepository(
    initial: [
      testParcel(id: 'a', sequence: 1, customerName: 'Ali Raza'),
      testParcel(
        id: 'b',
        sequence: 2,
        customerName: 'Sara Khan',
        received: 100000,
      ),
      testParcel(
        id: 'c',
        sequence: 3,
        customerName: 'Gift Three',
        method: CollectionMethod.giftFree,
      ),
      testParcel(
        id: 'd',
        sequence: 4,
        customerName: 'Returned Four',
        status: ParcelStatus.returned,
        received: 200000,
        paymentReviewRequired: true,
      ),
      testParcel(
        id: 'e',
        sequence: 5,
        customerName: 'Later Five',
        method: CollectionMethod.payLater,
        payDate: '2000-01-01',
      ),
    ],
  );

  testWidgets(
    'skeleton while loading, then the greeting, quick actions, every figure and recent parcels',
    (t) async {
      t.view.physicalSize = const Size(393, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
            parcelRepository: repo(),
            reminderScheduler: FakeReminderScheduler(),
            onOpenReminders: () {},
            onOpenParcel: (_) {},
            onOpenParcels: (_) {},
            onOpenPayments: () {},
            onAddParcel: () {},
          ),
        ),
      );
      expect(greetingWith('Ali'), findsOneWidget);
      await t.pump();
      await t.pump();
      expect(find.widgetWithText(FilledButton, 'Add Parcel'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Search'), findsOneWidget);
      // 5 parcels: sent = a, b, c, e; returned 1; free 1; money: received 1,000 + 2,000; owed 5,000 + 4,000 + 5,000.
      for (final (label, value) in [
        ('Total parcels', '5'),
        ('Sent', '4'),
        ('Returned', '1'),
        ('Gift / Free', '1'),
        ('Parcels with payment received', '2'),
        ('Parcels pending payment', '2'),
        ('Total received', 'Rs. 3,000'),
        ('Total outstanding', 'Rs. 14,000'),
        ('Pay Later balance', 'Rs. 5,000'),
        ('Advance amount', 'Rs. 0'),
        ('Overdue', '1'),
        ('Need payment review', '1'),
      ]) {
        expect(_card(label), findsOneWidget, reason: label);
        expect(
          find.bySemanticsLabel('$label: $value'),
          findsOneWidget,
          reason: '$label = $value',
        );
      }
      expect(find.text('Recent parcels'), findsOneWidget);
      expect(find.text('ADT-000005'), findsOneWidget);
      expect(
        find.textContaining('Reminders due today'),
        findsNothing,
        reason: 'an attention item shows only when something is in it',
      );
      expect(find.textContaining('Awaiting handover'), findsNothing);
      expect(find.textContaining('All caught up'), findsNothing);
    },
  );

  testWidgets(
    'each card opens the list or screen behind it; Add Parcel and Search work; a recent parcel opens',
    (t) async {
      final taps = await _pump(t, repo());
      await t.tap(_card('Sent'));
      await t.tap(_card('Returned'));
      await t.tap(_card('Gift / Free'));
      await t.tap(_card('Parcels with payment received'));
      await t.tap(_card('Parcels pending payment'));
      await t.tap(_card('Total parcels'));
      expect(taps.lists.map((f) => f.activeCount), [1, 1, 1, 1, 1, 0]);
      expect(taps.lists[0].statuses, {ParcelStatus.sent});
      expect(taps.lists[2].methods, {CollectionMethod.giftFree});
      expect(taps.lists[3].payments, {
        PaymentFilter.partial,
        PaymentFilter.received,
      });
      expect(taps.lists[4].payments, {PaymentFilter.pending});

      for (final money in [
        'Total received',
        'Total outstanding',
        'Pay Later balance',
        'Advance amount',
        'Need payment review',
      ]) {
        await t.tap(_card(money));
      }
      expect(taps.payments, 5);
      await t.tap(_card('Overdue'));
      expect(taps.reminders, 1);

      await t.tap(find.widgetWithText(FilledButton, 'Add Parcel'));
      expect(taps.adds, 1);
      await t.tap(find.widgetWithText(OutlinedButton, 'Search'));
      expect(taps.lists.last.isEmpty, isTrue);
      await t.tap(find.text('ADT-000005'));
      expect(taps.opened, ['e']);
    },
  );

  testWidgets(
    'a new user sees zeros and a friendly empty recent list; no review card until something needs review',
    (t) async {
      await _pump(t, FakeParcelRepository());
      expect(find.bySemanticsLabel('Total parcels: 0'), findsOneWidget);
      expect(find.bySemanticsLabel('Total outstanding: Rs. 0'), findsOneWidget);
      expect(find.textContaining('Need payment review'), findsNothing);
      expect(find.textContaining('All caught up'), findsOneWidget);
      expect(
        find.text('No parcels yet. Add your first parcel.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the figures follow the parcels live', (t) async {
    final parcels = repo();
    await _pump(t, parcels);
    expect(find.bySemanticsLabel('Total parcels: 5'), findsOneWidget);
    await parcels.create(_input());
    await t.pump();
    await t.pump();
    expect(find.bySemanticsLabel('Total parcels: 6'), findsOneWidget);
  });

  testWidgets('a load failure offers Retry', (t) async {
    final parcels = repo();
    await _pump(t, parcels);
    parcels.emitError(const AppFailure('No internet connection.'));
    await t.pump();
    await t.pump();
    expect(find.text("Couldn't load your figures"), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(find.bySemanticsLabel('Total parcels: 5'), findsOneWidget);
  });

  group('inside the app', () {
    testWidgets(
      'tapping Sent opens the Parcels tab already filtered to Sent parcels',
      (t) async {
        t.view.physicalSize = const Size(393, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          DelivTrackApp(
            repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
            productRepository: FakeProductRepository(),
            customerRepository: FakeCustomerRepository(),
            parcelRepository: repo(),
          ),
        );
        await t.pump(const Duration(milliseconds: 2000));
        await t.pumpAndSettle();
        await t.tap(_card('Returned'));
        await t.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
        expect(find.text('Status: Returned'), findsOneWidget);
        expect(find.text('Returned Four'), findsOneWidget);
        expect(find.text('Ali Raza'), findsNothing);

        // back to Home and pick another figure: the list switches to it (not stacked on the old one)
        await t.tap(tabButton('Home'));
        await t.pumpAndSettle();
        await t.tap(_card('Gift / Free'));
        await t.pumpAndSettle();
        expect(find.text('Type: Gift / Free'), findsOneWidget);
        expect(find.text('Status: Returned'), findsNothing);
        expect(find.text('Gift Three'), findsOneWidget);
      },
    );

    testWidgets(
      'Add Parcel opens the form; Total received opens the Payments tab; Search opens the full list',
      (t) async {
        t.view.physicalSize = const Size(393, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          DelivTrackApp(
            repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
            productRepository: FakeProductRepository(),
            customerRepository: FakeCustomerRepository(),
            parcelRepository: repo(),
          ),
        );
        await t.pump(const Duration(milliseconds: 2000));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Add Parcel'));
        await t.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Add parcel'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await t.tap(_card('Total received'));
        await t.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Payments'), findsOneWidget);
        await t.tap(tabButton('Home'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(OutlinedButton, 'Search'));
        await t.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Parcels'), findsOneWidget);
        expect(find.text('5 parcels'), findsOneWidget);
      },
    );
  });

  group('Home layout', () {
    testWidgets(
      'the order reads by importance: greeting, hero with the money to collect, actions, attention, parcels, money, recent',
      (t) async {
        await _pump(t, repo(), size: const Size(393, 3000));
        double top(Finder f) => t.getTopLeft(f.first).dy;
        final order = [
          top(greetingWith('Ali')),
          top(find.bySemanticsLabel(RegExp('^Total outstanding: '))),
          top(find.widgetWithText(FilledButton, 'Add Parcel')),
          top(find.text('Needs attention')),
          top(find.text('Parcels')),
          top(find.text('Money')),
          top(find.text('Recent parcels')),
        ];
        expect(order, [...order]..sort(), reason: 'top to bottom: $order');
        expect(find.text('Outstanding to collect'), findsOneWidget);
        expect(
          find.text('Rs. 14,000'),
          findsOneWidget,
          reason: 'the hero amount',
        );
        expect(find.text('3 parcels awaiting payment'), findsOneWidget);
        expect(find.text('Received Rs. 3,000'), findsOneWidget);
      },
    );

    testWidgets(
      'the greeting follows the Pakistan time of day and uses the first name',
      (t) async {
        for (final (utc, text) in [
          (DateTime.utc(2026, 11, 8, 2, 0), 'Good morning, Ali'), // 07:00 PKT
          (DateTime.utc(2026, 11, 8, 8, 0), 'Good afternoon, Ali'), // 13:00 PKT
          (DateTime.utc(2026, 11, 8, 14, 0), 'Good evening, Ali'), // 19:00 PKT
          (
            DateTime.utc(2026, 11, 8, 19, 30),
            'Good morning, Ali',
          ), // 00:30 PKT the next day
        ]) {
          await _pump(t, FakeParcelRepository(), clock: _FixedClock(utc));
          expect(find.text(text), findsOneWidget, reason: '$utc');
          await t.pumpWidget(const SizedBox());
        }
        await _pump(
          t,
          FakeParcelRepository(),
          clock: _FixedClock(DateTime.utc(2026, 11, 8, 8)),
        );
        expect(find.text('Sun, 8 Nov'), findsOneWidget);
      },
    );

    testWidgets('drafts show as "Awaiting handover" and open the Drafts list', (
      t,
    ) async {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            status: ParcelStatus.draft,
            reference: '',
            charge: null,
          ),
          testParcel(
            id: 'b',
            sequence: 2,
            status: ParcelStatus.draft,
            reference: '',
            charge: null,
          ),
          testParcel(id: 'c', sequence: 3),
        ],
      );
      final taps = await _pump(t, repo);
      expect(find.bySemanticsLabel('Awaiting handover: 2'), findsOneWidget);
      expect(find.textContaining('All caught up'), findsNothing);
      await t.tap(_card('Awaiting handover'));
      expect(taps.lists.single.statuses, {ParcelStatus.draft});
    });

    testWidgets(
      'due-today reminders appear as an attention item and open Reminders',
      (t) async {
        final today = pakistanDate(DateTime.now().toUtc());
        final repo = FakeParcelRepository(
          initial: [
            testParcel(
              id: 'a',
              method: CollectionMethod.payLater,
              service: PostalService.vpl,
              payDate: today,
            ),
          ],
        );
        final taps = await _pump(t, repo);
        expect(find.bySemanticsLabel('Reminders due today: 1'), findsOneWidget);
        await t.tap(_card('Reminders due today'));
        expect(taps.reminders, 1);
      },
    );

    testWidgets(
      '"Total outstanding" opens Payments; every figure of the old Home is still there',
      (t) async {
        final taps = await _pump(t, repo(), size: const Size(393, 3000));
        for (final label in [
          'Total parcels',
          'Sent',
          'Returned',
          'Gift / Free',
          'Parcels with payment received',
          'Parcels pending payment',
          'Total received',
          'Pay Later balance',
          'Advance amount',
          'Total outstanding',
          'Overdue',
          'Need payment review',
        ]) {
          expect(_card(label), findsOneWidget, reason: label);
        }
        await t.tap(_card('Total outstanding'));
        expect(taps.payments, 1);
      },
    );

    testWidgets(
      'View all opens the full list; a recent parcel opens its details',
      (t) async {
        final taps = await _pump(t, repo(), size: const Size(393, 3000));
        await t.tap(find.text('View all'));
        expect(taps.lists.single.isEmpty, isTrue);
      },
    );

    testWidgets(
      'on a normal phone the figures sit two to a row; at large text they stack in one column',
      (t) async {
        await _pump(t, repo(), size: const Size(360, 3000));
        final total = t.getTopLeft(find.bySemanticsLabel('Total parcels: 5'));
        final sent = t.getTopLeft(find.bySemanticsLabel('Sent: 4'));
        expect(sent.dy, total.dy, reason: 'two tiles in one row at 360 dp');
        await t.pumpWidget(const SizedBox());
        await _pump(t, repo(), size: const Size(360, 6000), scale: 2);
        final total2 = t.getTopLeft(find.bySemanticsLabel('Total parcels: 5'));
        final sent2 = t.getTopLeft(find.bySemanticsLabel('Sent: 4'));
        expect(
          sent2.dy,
          greaterThan(total2.dy),
          reason: 'one column at 2x text',
        );
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('all caught up: a calm line instead of an empty list', (
      t,
    ) async {
      await _pump(
        t,
        FakeParcelRepository(initial: [testParcel(id: 'a', received: 500000)]),
      );
      expect(find.textContaining('All caught up'), findsOneWidget);
    });
  });

  group('responsive', () {
    for (final size in const [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(1600, 900),
      Size(640, 300),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await _pump(t, repo(), size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -4000),
          );
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  group('unreadable parcels (DT-009)', () {
    testWidgets('nothing unreadable: no notice', (t) async {
      await _pump(t, FakeParcelRepository(initial: [testParcel(id: 'a')]));
      expect(find.textContaining("couldn't be read"), findsNothing);
    });

    testWidgets(
      'a damaged parcel is named by its document id only; the readable parcels still show',
      (t) async {
        final repo = FakeParcelRepository(
          initial: [
            testParcel(id: 'a'),
            testParcel(id: 'b', sequence: 2),
          ],
        )..unreadable = ['abc123'];
        await _pump(t, repo);
        expect(
          find.textContaining("1 parcel couldn't be read"),
          findsOneWidget,
        );
        expect(find.textContaining('abc123'), findsOneWidget);
        expect(find.bySemanticsLabel('Total parcels: 2'), findsOneWidget);
      },
    );

    testWidgets(
      'several damaged parcels: the first three ids and a count; stays readable at 2x text',
      (t) async {
        final repo = FakeParcelRepository(initial: [testParcel(id: 'a')])
          ..unreadable = ['d1', 'd2', 'd3', 'd4', 'd5'];
        await _pump(t, repo, size: const Size(360, 1800), scale: 2);
        expect(
          find.textContaining("5 parcels couldn't be read"),
          findsOneWidget,
        );
        expect(find.textContaining('d1, d2, d3 and 2 more'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });
}

class _FixedClock extends Clock {
  const _FixedClock(this.instant);
  final DateTime instant;
  @override
  DateTime nowUtc() => instant;
}
