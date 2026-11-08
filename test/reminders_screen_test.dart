import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/reminders/views/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';
import 'helpers/dropdown_finders.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

Parcel _later(
  String id,
  int sequence,
  String? date, {
  String name = 'Ali Raza',
  int received = 0,
}) => testParcel(
  id: id,
  sequence: sequence,
  customerName: name,
  method: CollectionMethod.payLater,
  payDate: date,
  received: received,
);

Future<List<Parcel>> _open(
  WidgetTester t,
  FakeParcelRepository repo, {
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final opened = <Parcel>[];
  await t.pumpWidget(
    MaterialApp(
      home: RemindersScreen(
        repository: repo,
        onOpen: opened.add,
        clock: const _Clock(),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return opened;
}

void main() {
  testWidgets('sections in order with counts; rows say how late or when due', (
    t,
  ) async {
    await _open(
      t,
      FakeParcelRepository(
        initial: [
          _later('a', 1, '2026-11-07'),
          _later('b', 2, '2026-11-10', name: 'Sara Khan'),
          _later('c', 3, '2026-11-09', name: 'Bilal'),
          _later('d', 4, '2026-12-25', name: 'Omar'),
          _later('e', 5, null, name: 'Zainab'),
        ],
      ),
      size: const Size(393, 1800),
    );
    final headers = [
      'Overdue (2)',
      'Due today (1)',
      'Upcoming (1)',
      'No date set (1)',
    ];
    for (final header in headers) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    final order = [
      for (final header in headers) t.getTopLeft(find.text(header)).dy,
    ];
    expect(
      order,
      [...order]..sort(),
      reason: 'sections run Overdue, Due today, Upcoming, No date set',
    );
    expect(find.text('Overdue by 3 days · 7 Nov 2026'), findsOneWidget);
    expect(find.text('Overdue by 1 day · 9 Nov 2026'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Due 25 Dec 2026'), findsOneWidget);
    expect(find.text('No date set'), findsOneWidget);
    expect(find.text('Outstanding Rs. 5,000'), findsNWidgets(5));
  });

  testWidgets('only Pay Later parcels that still owe money are listed', (
    t,
  ) async {
    await _open(
      t,
      FakeParcelRepository(
        initial: [
          _later('a', 1, '2026-11-12'),
          _later('paid', 2, '2026-11-12', received: 500000),
          testParcel(id: 'collect', sequence: 3),
          testParcel(
            id: 'ret',
            sequence: 4,
            method: CollectionMethod.payLater,
            status: ParcelStatus.returned,
            payDate: '2026-11-12',
          ),
        ],
      ),
    );
    expect(find.text('ADT-000001'), findsOneWidget);
    expect(find.text('ADT-000002'), findsNothing);
    expect(find.text('ADT-000003'), findsNothing);
    expect(find.text('ADT-000004'), findsNothing);
  });

  testWidgets('nothing to follow up shows an empty state', (t) async {
    await _open(t, FakeParcelRepository(initial: [testParcel()]));
    expect(find.text('Nothing to follow up'), findsOneWidget);
  });

  testWidgets('a load failure offers Retry', (t) async {
    final repo = FakeParcelRepository(initial: [_later('a', 1, null)]);
    await _open(t, repo);
    repo.emitError(const AppFailure('No internet connection.'));
    await t.pump();
    await t.pump();
    expect(find.text("Couldn't load reminders"), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(find.text('ADT-000001'), findsOneWidget);
  });

  testWidgets('tapping a row opens that parcel', (t) async {
    final opened = await _open(
      t,
      FakeParcelRepository(initial: [_later('a', 1, '2026-11-12')]),
    );
    await t.tap(find.text('ADT-000001'));
    expect(opened.single.id, 'a');
  });

  testWidgets(
    'Mark Received records a payment; once paid in full the row leaves the list',
    (t) async {
      final repo = FakeParcelRepository(
        initial: [_later('a', 1, '2026-11-09')],
      );
      await _open(t, repo);
      await t.tap(find.text('Mark Received'));
      await t.pumpAndSettle();
      await chooseOption(t, 'Payment type', 'Customer payment');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
      await t.pumpAndSettle();
      expect(find.text('Payment recorded.'), findsOneWidget);
      expect(find.text('Nothing to follow up'), findsOneWidget);
    },
  );

  testWidgets(
    'a parcel without a date offers Set Date, which opens the date sheet',
    (t) async {
      final repo = FakeParcelRepository(initial: [_later('a', 1, null)]);
      await _open(t, repo);
      expect(find.text('Set Date'), findsOneWidget);
      expect(find.text('Change Date'), findsNothing);
      await t.tap(find.text('Set Date'));
      await t.pumpAndSettle();
      expect(find.text('Pay Later date'), findsOneWidget);
    },
  );

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
              initial: [
                _later(
                  'a',
                  1,
                  '2026-11-01',
                  name: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman',
                ),
                _later('b', 2, '2026-11-10'),
                _later('c', 3, '2031-01-01'),
                _later('d', 4, null),
              ],
            ),
            size: size,
            scale: scale,
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
