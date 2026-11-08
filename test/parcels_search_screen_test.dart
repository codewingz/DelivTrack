import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_search.dart';
import 'package:deliv_track/features/parcels/views/parcel_filter_sheet.dart';
import 'package:deliv_track/features/parcels/views/parcels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

Future<void> _pump(
  WidgetTester t,
  FakeParcelRepository repo, {
  Size size = const Size(393, 1400),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    MaterialApp(
      home: ParcelsScreen(
        repository: repo,
        onAdd: () async {},
        onOpen: (_) {},
        clock: const _Clock(),
      ),
    ),
  );
  await t.pump();
  await t.pump();
}

FakeParcelRepository _repo() => FakeParcelRepository(
  initial: [
    testParcel(
      id: 'a',
      sequence: 1,
      customerName: 'Ali Raza',
      reference: 'VPP 11111',
      method: CollectionMethod.advance,
    ),
    testParcel(
      id: 'b',
      sequence: 2,
      customerName: 'Sara Khan',
      reference: 'VPP 22222',
    ),
    testParcel(
      id: 'c',
      sequence: 3,
      customerName: 'Bilal Ahmed',
      reference: 'VPL 33333',
      method: CollectionMethod.payLater,
      payDate: '2026-11-01',
    ),
  ],
);

Finder get _searchField => find.byType(TextFormField).first;

void main() {
  group('search', () {
    testWidgets(
      'waits 300 ms after the last keystroke, then narrows; the count follows',
      (t) async {
        await _pump(t, _repo());
        expect(find.text('3 parcels'), findsOneWidget);
        await t.enterText(_searchField, 'sara');
        await t.pump(const Duration(milliseconds: 299));
        expect(find.text('Ali Raza'), findsOneWidget, reason: 'not yet');
        await t.pump(const Duration(milliseconds: 2));
        expect(find.text('Ali Raza'), findsNothing);
        expect(find.text('Sara Khan'), findsOneWidget);
        expect(find.text('1 match'), findsOneWidget);
      },
    );

    testWidgets(
      'typing again restarts the wait (one search for a burst of keystrokes)',
      (t) async {
        await _pump(t, _repo());
        await t.enterText(_searchField, 's');
        await t.pump(const Duration(milliseconds: 200));
        await t.enterText(_searchField, 'sa');
        await t.pump(const Duration(milliseconds: 200));
        expect(
          find.text('3 parcels'),
          findsOneWidget,
          reason: '400 ms in total, but never 300 ms without typing',
        );
        await t.pump(const Duration(milliseconds: 150));
        expect(find.text('1 match'), findsOneWidget);
      },
    );

    for (final (query, expected) in [
      ('ADT-000003', 'Bilal Ahmed'),
      ('3', 'Bilal Ahmed'),
      ('vpp 11111', 'Ali Raza'),
      ('22222', 'Sara Khan'),
      ('bilal', 'Bilal Ahmed'),
      ('mango', 'Ali Raza'),
    ]) {
      testWidgets('finds by "$query"', (t) async {
        await _pump(t, _repo());
        await t.enterText(_searchField, query);
        await t.pump(const Duration(milliseconds: 350));
        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('no matches: explains and Clear brings everything back', (
      t,
    ) async {
      await _pump(t, _repo());
      await t.enterText(_searchField, 'zzzz');
      await t.pump(const Duration(milliseconds: 350));
      expect(find.text('No parcels match'), findsOneWidget);
      await t.tap(find.text('Clear search and filters'));
      await t.pump();
      expect(find.text('3 parcels'), findsOneWidget);
      expect(t.widget<TextFormField>(_searchField).controller!.text, isEmpty);
    });

    testWidgets(
      'a pending search is dropped when the screen goes away (no timer is left running)',
      (t) async {
        await _pump(t, _repo());
        await t.enterText(_searchField, 'sara');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      },
    );
  });

  group('filters', () {
    Future<void> openFilters(WidgetTester t) async {
      await t.tap(find.widgetWithText(OutlinedButton, 'Filters'));
      await t.pumpAndSettle();
    }

    Future<void> apply(WidgetTester t) async {
      await t.ensureVisible(find.widgetWithText(FilledButton, 'Apply Filters'));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'parcel type: choose, apply; the chip and the badge show it; the chip removes it',
      (t) async {
        await _pump(t, _repo());
        await openFilters(t);
        await t.tap(find.widgetWithText(FilterChip, 'Advance paid'));
        await t.pump();
        await apply(t);
        expect(find.text('Ali Raza'), findsOneWidget);
        expect(find.text('Sara Khan'), findsNothing);
        expect(find.text('Type: Advance paid'), findsOneWidget);
        expect(
          find.descendant(of: find.byType(Badge), matching: find.text('1')),
          findsOneWidget,
        );
        expect(find.text('1 match'), findsOneWidget);
        await t.tap(find.byTooltip('Delete'));
        await t.pump();
        expect(find.text('3 parcels'), findsOneWidget);
        expect(find.text('Type: Advance paid'), findsNothing);
      },
    );

    testWidgets(
      'payment status Overdue and parcel status can be combined with search',
      (t) async {
        await _pump(t, _repo());
        await openFilters(t);
        await t.tap(find.widgetWithText(FilterChip, 'Overdue'));
        await t.pump();
        await apply(t);
        expect(find.text('Bilal Ahmed'), findsOneWidget);
        expect(find.text('Ali Raza'), findsNothing);
        await t.enterText(_searchField, 'sara');
        await t.pump(const Duration(milliseconds: 350));
        expect(
          find.text('No parcels match'),
          findsOneWidget,
          reason: 'overdue AND named Sara matches nothing',
        );
      },
    );

    testWidgets(
      'reopening the sheet shows the current choices; Reset all clears them',
      (t) async {
        await _pump(t, _repo());
        await openFilters(t);
        await t.tap(find.widgetWithText(FilterChip, 'Sent'));
        await t.pump();
        await apply(t);
        await openFilters(t);
        expect(
          t
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sent'))
              .selected,
          isTrue,
        );
        await t.tap(find.text('Reset all'));
        await t.pump();
        expect(
          t
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sent'))
              .selected,
          isFalse,
        );
        await apply(t);
        expect(find.text('Status: Sent'), findsNothing);
        expect(find.text('3 parcels'), findsOneWidget);
      },
    );

    testWidgets('the product filter lists the products on the parcels', (
      t,
    ) async {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            sequence: 1,
            customerName: 'Ali Raza',
            items: [
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Mango Box',
                quantity: 1,
                unitPricePaisa: 100000,
              ),
            ],
          ),
          testParcel(
            id: 'b',
            sequence: 2,
            customerName: 'Sara Khan',
            items: [
              ParcelItem.pieces(
                productId: 'p2',
                productName: 'Honey Jar',
                quantity: 1,
                unitPricePaisa: 100000,
              ),
            ],
          ),
        ],
      );
      await _pump(t, repo);
      await openFilters(t);
      await t.ensureVisible(find.text('Any product'));
      await t.tap(find.text('Any product'));
      await t.pumpAndSettle();
      await t.tap(find.text('Honey Jar'));
      await t.pumpAndSettle();
      await apply(t);
      expect(find.text('Sara Khan'), findsOneWidget);
      expect(find.text('Ali Raza'), findsNothing);
      expect(find.text('Product: Honey Jar'), findsOneWidget);
    });

    testWidgets(
      'a date range that ends before it starts is refused in the sheet',
      (t) async {
        await _pump(t, _repo());
        ParcelFilters? result;
        final context = t.element(find.byType(ParcelsScreen));
        showParcelFilterSheet(
          context,
          current: const ParcelFilters(
            sendingFrom: '2026-11-10',
            sendingTo: '2026-11-01',
          ),
          products: const [],
          today: '2026-11-10',
        ).then((f) => result = f);
        await t.pumpAndSettle();
        await t.ensureVisible(
          find.widgetWithText(FilledButton, 'Apply Filters'),
        );
        await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Apply Filters'));
        await t.pumpAndSettle();
        expect(
          find.text('The sending date range ends before it starts.'),
          findsOneWidget,
        );
        expect(result, isNull, reason: 'the sheet stays open');
      },
    );
  });

  group('load more', () {
    testWidgets(
      'shows 20 rows and a Load more button until everything is shown',
      (t) async {
        await _pump(
          t,
          FakeParcelRepository(
            initial: [
              for (var i = 1; i <= 25; i++) testParcel(id: 'p$i', sequence: i),
            ],
          ),
          size: const Size(393, 9000),
        );
        expect(find.byType(ParcelTile), findsNWidgets(20));
        await t.tap(find.text('Load more'));
        await t.pump();
        expect(find.byType(ParcelTile), findsNWidgets(25));
        expect(find.text('Load more'), findsNothing);
      },
    );
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
        testWidgets(
          'no overflow at $size text x$scale (with a filter and a search)',
          (t) async {
            await _pump(t, _repo(), size: size, scale: scale);
            expect(t.takeException(), isNull);
            await t.enterText(_searchField, 'a');
            await t.pump(const Duration(milliseconds: 350));
            await t.tap(find.widgetWithText(OutlinedButton, 'Filters'));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await t.ensureVisible(
              find.widgetWithText(FilledButton, 'Apply Filters'),
            );
            await t.pump();
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  });
}
