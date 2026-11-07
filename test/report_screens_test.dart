import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/reports/domain/reports.dart';
import 'package:deliv_track/features/reports/viewmodel/report_view_model.dart';
import 'package:deliv_track/features/reports/views/reports_screens.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

Future<List<String>> _open(WidgetTester t, ReportType type, FakeParcelRepository repo, {Size size = const Size(393, 1400), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final opened = <String>[];
  await t.pumpWidget(MaterialApp(home: ReportScreen(repository: repo, type: type, onOpenParcel: opened.add, clock: const _Clock())));
  await t.pump();
  await t.pump();
  await t.pump();
  return opened;
}

FakeParcelRepository _repo() {
  final repo = FakeParcelRepository(initial: [
    testParcel(id: 'a', sequence: 1, customerName: 'Ali Raza', sendingDate: '2026-11-01'),
    testParcel(id: 'b', sequence: 2, customerName: 'Sara Khan', sendingDate: '2026-11-05', received: 200000),
  ]);
  repo.payments['b'] = [Payment(id: 'b1', amountPaisa: 200000, type: PaymentType.advance, note: null, receivedAt: DateTime.utc(2026, 11, 8, 6))];
  return repo;
}

void main() {
  testWidgets('the list shows every report with its description and opens the chosen one', (t) async {
    final opened = <ReportType>[];
    await t.pumpWidget(MaterialApp(home: ReportsScreen(onOpen: opened.add)));
    for (final type in ReportType.values) {
      expect(find.text(type.title), findsOneWidget, reason: type.title);
    }
    await t.tap(find.text('Outstanding payments'));
    expect(opened, [ReportType.outstanding]);
  });

  testWidgets('a report shows its rows, a row opens the parcel, and the totals are pinned below', (t) async {
    final opened = await _open(t, ReportType.outstanding, _repo());
    expect(find.text('ADT-000002 · Sara Khan'), findsOneWidget);
    expect(find.text('Expected Rs. 5,000 · Received Rs. 2,000'), findsOneWidget);
    expect(find.text('Total outstanding Rs. 8,000'), findsOneWidget);
    expect(find.text('2 parcels'), findsOneWidget);
    await t.tap(find.text('ADT-000001 · Ali Raza'));
    expect(opened, ['a']);
  });

  testWidgets('the payment history is loaded from the payments', (t) async {
    await _open(t, ReportType.paymentHistory, _repo());
    expect(find.text('8 Nov 2026 · Advance'), findsOneWidget);
    expect(find.text('Total received Rs. 2,000'), findsOneWidget);
    expect(find.text('1 payment'), findsOneWidget);
  });

  testWidgets('nothing matching: an empty state, and totals of zero stay visible', (t) async {
    await _open(t, ReportType.returned, _repo());
    expect(find.text('Nothing to report'), findsOneWidget);
    expect(find.text('0 returned parcels'), findsOneWidget);
  });

  test('a date range narrows the report; a range that ends before it starts is refused', () async {
    final repo = _repo();
    final vm = ReportViewModel(repo, ReportType.outstanding, clock: const _Clock());
    await Future<void>.delayed(Duration.zero);
    expect(vm.result!.rows, hasLength(2));
    vm.setRange(from: '2026-11-03');
    expect(vm.result!.rows.map((r) => r.parcelId), ['b']);
    vm.setRange(from: '2026-11-10', to: '2026-11-01');
    expect(vm.rangeProblem, 'The To date is before the From date.');
    expect(vm.result, isNull);
    vm.setRange(from: '2026-11-01', to: '2026-11-10');
    expect(vm.result!.rows, hasLength(2));
    vm.dispose();
  });

  testWidgets('a load failure offers Retry', (t) async {
    final repo = _repo();
    await _open(t, ReportType.outstanding, repo);
    repo.emitError(const AppFailure('No internet connection.'));
    await t.pump();
    await t.pump();
    expect(find.text("Couldn't load the report"), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(find.text('ADT-000001 · Ali Raza'), findsOneWidget);
  });

  testWidgets('a failure fetching the payments is kept apart and can be retried', (t) async {
    final repo = _repo();
    repo.failure = const AppFailure('No internet connection.');
    await _open(t, ReportType.paymentHistory, repo);
    expect(find.text("Couldn't load the payments"), findsOneWidget);
    repo.failure = null;
    await t.tap(find.text('Retry'));
    await t.pump();
    await t.pump();
    expect(find.text('Total received Rs. 2,000'), findsOneWidget);
  });

  group('inside the app', () {
    testWidgets('More -> Reports -> a report -> a parcel, and back', (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(DelivTrackApp(
        repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
        productRepository: FakeProductRepository(),
        customerRepository: FakeCustomerRepository(),
        parcelRepository: _repo(),
      ));
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Reports'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
      await t.tap(find.text('Outstanding payments'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Outstanding payments'), findsOneWidget);
      await t.tap(find.text('ADT-000002 · Sara Khan'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'ADT-000002'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
    });
  });

  group('responsive', () {
    for (final type in [ReportType.outstanding, ReportType.paymentHistory, ReportType.productWise]) {
      for (final size in const [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('${type.name}: no overflow at $size text x$scale', (t) async {
            await _open(t, type, _repo(), size: size, scale: scale);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  });
}
