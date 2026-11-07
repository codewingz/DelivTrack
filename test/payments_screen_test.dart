import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/payments/domain/payment_tabs.dart';
import 'package:deliv_track/features/payments/viewmodel/payments_view_model.dart';
import 'package:deliv_track/features/payments/views/payments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

Future<List<Parcel>> _open(WidgetTester t, FakeParcelRepository repo, {Size size = const Size(393, 1200), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final opened = <Parcel>[];
  await t.pumpWidget(MaterialApp(home: PaymentsScreen(repository: repo, onOpen: opened.add, clock: const _Clock())));
  await t.pump();
  await t.pump();
  return opened;
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

/// The tab row scrolls sideways, so bring the chip into view before tapping it.
Future<void> _pick(WidgetTester t, String label) async {
  // On a very small screen the totals fill it, so the tabs may first need a vertical scroll.
  await t.scrollUntilVisible(_chip(label), 100, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(_chip(label));
  await t.pump();
  await t.tap(_chip(label));
  await t.pump();
}

void main() {
  testWidgets('totals on top; opens on Pending; each tab lists its parcels', (t) async {
    await _open(
      t,
      FakeParcelRepository(initial: [
        testParcel(id: 'a', sequence: 1, customerName: 'Pending One'),
        testParcel(id: 'b', sequence: 2, customerName: 'Part Two', received: 200000),
        testParcel(id: 'c', sequence: 3, customerName: 'Paid Three', received: 500000),
        testParcel(id: 'd', sequence: 4, customerName: 'Later Four', method: CollectionMethod.payLater, payDate: '2026-11-01'),
        testParcel(id: 'e', sequence: 5, customerName: 'Advance Five', method: CollectionMethod.advance, received: 300000),
        testParcel(id: 'f', sequence: 6, customerName: 'Gift Six', method: CollectionMethod.giftFree),
        testParcel(id: 'g', sequence: 7, customerName: 'Returned Seven', status: ParcelStatus.returned, paymentReviewRequired: true),
      ]),
    );
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Pay Later balance'), findsOneWidget);
    expect(find.text('Advance received'), findsOneWidget);
    expect(find.text('Rs. 15,000'), findsOneWidget, reason: '5,000 + 3,000 + 5,000 + 2,000 owed (the paid parcel owes nothing)');
    expect(find.text('Pending One'), findsOneWidget);
    expect(find.text('Part Two'), findsNothing);

    Future<void> show(String tab, List<String> names, List<String> hidden) async {
      await _pick(t, tab);
      for (final name in names) {
        expect(find.text(name), findsOneWidget, reason: '$name under $tab');
      }
      for (final name in hidden) {
        expect(find.text(name), findsNothing, reason: '$name not under $tab');
      }
    }

    await show('Partially paid', ['Part Two', 'Advance Five'], ['Pending One']);
    await show('Received', ['Paid Three'], ['Part Two']);
    await show('Advance', ['Advance Five'], ['Paid Three']);
    await show('Pay Later', ['Later Four'], ['Advance Five']);
    await show('Overdue', ['Later Four'], ['Pending One']);
    await show('Review', ['Returned Seven'], ['Later Four']);
    expect(find.text('Gift Six'), findsNothing, reason: 'Gift / Free is never listed');
  });

  testWidgets('a row shows expected, received, balance and the Pay Later date; overdue is flagged', (t) async {
    await _open(t, FakeParcelRepository(initial: [testParcel(id: 'a', received: 100000, method: CollectionMethod.payLater, payDate: '2026-11-01')]));
    await _pick(t, 'Overdue');
    expect(find.text('Expected Rs. 5,000 · Received Rs. 1,000'), findsOneWidget);
    expect(find.text('Balance Rs. 4,000'), findsOneWidget);
    expect(find.text('Pay Later date 1 Nov 2026'), findsOneWidget);
  });

  testWidgets('empty tab explains what belongs there', (t) async {
    await _open(t, FakeParcelRepository());
    await _pick(t, 'Overdue');
    expect(find.text('Nothing in Overdue'), findsOneWidget);
    expect(find.textContaining('past their date'), findsOneWidget);
  });

  testWidgets('tapping a row opens the parcel; Receive records a payment and the row moves on', (t) async {
    final repo = FakeParcelRepository(initial: [testParcel(id: 'a', customerName: 'Pending One')]);
    final opened = await _open(t, repo);
    await t.tap(find.text('Pending One'));
    expect(opened.single.id, 'a');

    await t.tap(find.text('Receive'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Customer payment'));
    await t.enterText(find.byType(TextFormField).first, '5000');
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
    await t.pumpAndSettle();
    expect(find.text('Payment recorded.'), findsOneWidget);
    expect(find.text('Pending One'), findsNothing, reason: 'paid in full leaves Pending');
    await _pick(t, 'Received');
    expect(find.text('Pending One'), findsOneWidget);
    expect(find.text('Receive'), findsNothing, reason: 'nothing left to receive');
  });

  testWidgets('a returned parcel in Review has no Receive button', (t) async {
    await _open(t, FakeParcelRepository(initial: [testParcel(id: 'a', status: ParcelStatus.returned, paymentReviewRequired: true)]));
    await _pick(t, 'Review');
    expect(find.text('Requires payment review'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
  });

  testWidgets('a load failure offers Retry', (t) async {
    final repo = FakeParcelRepository(initial: [testParcel(id: 'a', customerName: 'Pending One')]);
    await _open(t, repo);
    repo.emitError(const AppFailure('No internet connection.'));
    await t.pump();
    await t.pump();
    expect(find.text("Couldn't load payments"), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(find.text('Pending One'), findsOneWidget);
  });

  group('paging', () {
    test('20 at a time; Show more adds the next 20; changing the tab starts again', () async {
      final repo = FakeParcelRepository(initial: [for (var i = 1; i <= 45; i++) testParcel(id: 'p$i', sequence: i)]);
      final vm = PaymentsViewModel(repo, clock: const _Clock());
      await Future<void>.delayed(Duration.zero);
      expect(vm.matching, hasLength(45));
      expect(vm.visible, hasLength(20));
      expect(vm.hasMore, isTrue);
      vm.showMore();
      expect(vm.visible, hasLength(40));
      vm.showMore();
      expect(vm.visible, hasLength(45));
      expect(vm.hasMore, isFalse);
      vm.select(PaymentTab.received);
      vm.select(PaymentTab.pending);
      expect(vm.visible, hasLength(20), reason: 'back to the first page');
      expect(vm.visible.first.id, 'p45', reason: 'newest first');
      vm.dispose();
    });

    testWidgets('the screen shows Show more only while there is more', (t) async {
      await _open(t, FakeParcelRepository(initial: [for (var i = 1; i <= 21; i++) testParcel(id: 'p$i', sequence: i)]), size: const Size(393, 9000));
      expect(find.text('Receive'), findsNWidgets(20));
      await t.tap(find.text('Show more'));
      await t.pump();
      expect(find.text('Receive'), findsNWidgets(21));
      expect(find.text('Show more'), findsNothing);
    });
  });

  group('responsive', () {
    for (final size in const [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await _open(
            t,
            FakeParcelRepository(initial: [
              testParcel(id: 'a', sequence: 1, customerName: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman', method: CollectionMethod.payLater, payDate: '2026-11-01'),
              testParcel(id: 'b', sequence: 2),
            ]),
            size: size,
            scale: scale,
          );
          expect(t.takeException(), isNull);
          await _pick(t, 'Overdue');
          expect(t.takeException(), isNull);
          await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
