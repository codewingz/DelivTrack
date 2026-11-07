import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/parcels/views/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

// Order total Rs. 5,000.
Parcel _parcel({int received = 0}) => testParcel(id: 'a', received: received);

Future<({FakeParcelRepository repo, List<bool?> results})> _open(
  WidgetTester t, {
  int received = 0,
  Size size = const Size(393, 852),
  double scale = 1,
  FakeParcelRepository? repo,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final parcel = _parcel(received: received);
  final repository = repo ?? FakeParcelRepository(initial: [parcel]);
  final results = <bool?>[];
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => results.add(await showPaymentSheet(context, repository, parcel)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return (repo: repository, results: results);
}

Finder get _confirm => find.widgetWithText(FilledButton, 'Confirm Payment');
Finder get _amountField => find.byType(TextFormField).first;

void main() {
  testWidgets('opens with the outstanding balance filled in and no type chosen', (t) async {
    await _open(t, received: 200000);
    expect(find.text('ADT-000001 · Outstanding Rs. 3,000'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    for (final type in PaymentType.values) {
      expect(find.widgetWithText(ChoiceChip, type.label), findsOneWidget);
    }
    expect(find.text('Select a payment type'), findsNothing);
  });

  testWidgets('confirming without a type shows the error and records nothing', (t) async {
    final env = await _open(t);
    await t.tap(_confirm);
    await t.pump();
    expect(find.text('Select a payment type'), findsOneWidget);
    expect(env.repo.paymentRecords, 0);
  });

  testWidgets('amount: empty, zero and above the outstanding balance are refused', (t) async {
    final env = await _open(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.pump();
    for (final entry in {'': 'Amount received is required', '0': 'Enter an amount above zero', '5000.01': 'Cannot exceed outstanding Rs. 5,000'}.entries) {
      await t.enterText(_amountField, entry.key);
      await t.pump();
      await t.tap(_confirm);
      await t.pump();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
    expect(env.repo.paymentRecords, 0);
  });

  testWidgets('a note longer than 200 characters is refused', (t) async {
    final env = await _open(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.enterText(find.byType(TextFormField).last, 'x' * 201);
    await t.pump();
    await t.tap(_confirm);
    await t.pump();
    expect(find.text('Use at most 200 characters'), findsOneWidget);
    expect(env.repo.paymentRecords, 0);
  });

  testWidgets('a valid payment is recorded once and the sheet closes with true', (t) async {
    final env = await _open(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Post office remittance'));
    await t.enterText(_amountField, '1500.50');
    await t.enterText(find.byType(TextFormField).last, '  first  part ');
    await t.pump();
    await t.tap(_confirm);
    await t.pumpAndSettle();
    expect(env.repo.paymentRecords, 1);
    final payment = env.repo.payments['a']!.single;
    expect(payment.amountPaisa, 150050);
    expect(payment.type, PaymentType.postOfficeRemittance);
    expect(payment.note, 'first part');
    expect(env.results, [true]);
    expect(find.text('Mark payment received'), findsNothing);
  });

  testWidgets('repeated taps while saving record one payment', (t) async {
    final repo = FakeParcelRepository(initial: [_parcel()])..gate = Completer<void>();
    await _open(t, repo: repo);
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.pump();
    await t.tap(_confirm);
    await t.pump();
    await t.tap(find.byType(FilledButton), warnIfMissed: false);
    await t.pump();
    expect(repo.paymentRecords, 1);
    repo.gate!.complete();
    await t.pumpAndSettle();
    expect(repo.payments['a'], hasLength(1));
  });

  testWidgets('a failure is shown in the sheet, which stays open with the values', (t) async {
    final repo = FakeParcelRepository(initial: [_parcel()], failure: const AppFailure('No internet connection.'));
    final env = await _open(t, repo: repo);
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.pump();
    await t.tap(_confirm);
    await t.pumpAndSettle();
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Mark payment received'), findsOneWidget);
    expect(env.results, isEmpty);
  });

  testWidgets('Entered late? reveals Received on; submitting without a day is refused', (t) async {
    final env = await _open(t);
    expect(find.text('Received on'), findsNothing);
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(find.text('Received on'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
    await t.pump();
    await t.ensureVisible(_confirm);
    await t.tap(_confirm);
    await t.pump();
    expect(find.text('Select the day it was received.'), findsOneWidget);
    expect(env.repo.paymentRecords, 0);
  });

  group('responsive', () {
    for (final size in const [Size(320, 568), Size(393, 852), Size(700, 900), Size(640, 300)]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale (with errors)', (t) async {
          await _open(t, size: size, scale: scale);
          await t.enterText(_amountField, '99999');
          await t.pump();
          await t.ensureVisible(_confirm);
          await t.tap(_confirm);
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
