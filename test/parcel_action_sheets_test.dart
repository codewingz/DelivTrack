import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/parcels/views/parcel_action_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

class _Clock extends Clock {
  const _Clock();
  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 10, 6);
}

typedef _Opener = Future<bool> Function(BuildContext context, FakeParcelRepository repo, Parcel parcel);

Future<({FakeParcelRepository repo, List<bool> results})> _open(
  WidgetTester t,
  Parcel parcel,
  _Opener opener, {
  FakeParcelRepository? repo,
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final repository = repo ?? FakeParcelRepository(initial: [parcel]);
  final results = <bool>[];
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(child: ElevatedButton(onPressed: () async => results.add(await opener(context, repository, parcel)), child: const Text('open'))),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return (repo: repository, results: results);
}

Finder get _submit => find.byType(FilledButton);
Finder get _fields => find.byType(TextFormField);

Parcel _sent({int received = 0, String? notes, String? payDate, CollectionMethod method = CollectionMethod.postalCollection}) =>
    testParcel(id: 'a', received: received, notes: notes, payDate: payDate, method: method, service: method == CollectionMethod.payLater ? PostalService.vpl : PostalService.vpp);

void main() {
  group('Mark Returned', () {
    Future<bool> open(BuildContext c, FakeParcelRepository r, Parcel p) => showReturnSheet(c, r, p, clock: const _Clock());

    testWidgets('shows today, warns that nothing is refunded, and records the return once', (t) async {
      final env = await _open(t, _sent(received: 100000), open);
      expect(find.text('10 Nov 2026'), findsOneWidget);
      expect(find.textContaining('Nothing is refunded automatically'), findsOneWidget);
      await t.enterText(_fields.last, '  Customer   refused ');
      await t.pump();
      await t.tap(_submit);
      await t.pumpAndSettle();
      expect(env.repo.returns.single, (id: 'a', date: '2026-11-10', reason: 'Customer refused'));
      expect(env.results, [true]);
    });

    testWidgets('a reason over 200 characters is refused', (t) async {
      final env = await _open(t, _sent(), open);
      await t.enterText(_fields.last, 'x' * 201);
      await t.pump();
      await t.tap(_submit);
      await t.pump();
      expect(find.text('Use at most 200 characters'), findsOneWidget);
      expect(env.repo.returns, isEmpty);
    });

    testWidgets('a failure stays in the sheet', (t) async {
      final repo = FakeParcelRepository(initial: [_sent()], failure: const AppFailure('No internet connection.'));
      final env = await _open(t, _sent(), open, repo: repo);
      await t.tap(_submit);
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(find.text('Mark as returned'), findsOneWidget);
      expect(env.results, isEmpty);
    });
  });

  group('Notes', () {
    testWidgets('prefilled; saves trimmed text; an empty note is allowed (it removes the notes)', (t) async {
      final env = await _open(t, _sent(notes: 'Call first'), showNotesSheet);
      expect(find.text('Call first'), findsOneWidget);
      await t.enterText(_fields.first, '');
      await t.pump();
      await t.tap(_submit);
      await t.pumpAndSettle();
      expect(env.repo.notesSaved.single, (id: 'a', notes: ''));
      expect(env.results, [true]);
    });

    testWidgets('more than 500 characters is refused', (t) async {
      final env = await _open(t, _sent(), showNotesSheet);
      await t.enterText(_fields.first, 'x' * 501);
      await t.pump();
      await t.tap(_submit);
      await t.pump();
      expect(find.text('Use at most 500 characters'), findsOneWidget);
      expect(env.repo.notesSaved, isEmpty);
    });
  });

  group('Pay Later date', () {
    Future<bool> open(BuildContext c, FakeParcelRepository r, Parcel p) => showPayLaterDateSheet(c, r, p, clock: const _Clock());

    testWidgets('shows the current date; clearing it turns the button into Clear Date and saves null', (t) async {
      final env = await _open(t, _sent(method: CollectionMethod.payLater, payDate: '2031-02-03'), open);
      expect(find.text('3 Feb 2031'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save Date'), findsOneWidget);
      await t.tap(find.byTooltip('Clear date'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Clear Date'), findsOneWidget);
      await t.tap(_submit);
      await t.pumpAndSettle();
      expect(env.repo.payDates.single, (id: 'a', date: null));
      expect(env.results, [true]);
    });
  });

  group('Correct payment', () {
    // Rs. 2,000 of Rs. 5,000 received as payment "pay-1".
    final payment = Payment(id: 'pay-1', amountPaisa: 200000, type: PaymentType.advance, note: null, receivedAt: DateTime.utc(2026, 11, 8, 6));
    Future<({FakeParcelRepository repo, List<bool> results})> openCorrect(WidgetTester t, {Size size = const Size(393, 852), double scale = 1}) {
      final parcel = _sent(received: 200000);
      final repo = FakeParcelRepository(initial: [parcel])..payments['a'] = [payment];
      return _open(t, parcel, (c, r, p) => showCorrectPaymentSheet(c, r, p, payment), repo: repo, size: size, scale: scale);
    }

    testWidgets('prefilled with the payment; a reason is required; the same amount is refused', (t) async {
      final env = await openCorrect(t);
      expect(find.text('2000'), findsOneWidget);
      await t.tap(_submit);
      await t.pump();
      expect(find.text('Enter a different amount'), findsOneWidget);
      expect(find.text('Reason for the correction is required'), findsOneWidget);
      expect(env.repo.corrections, isEmpty);
    });

    testWidgets('more than the order can take is refused', (t) async {
      final env = await openCorrect(t);
      await t.enterText(_fields.first, '5000.01');
      await t.enterText(_fields.last, 'Wrong amount entered');
      await t.pump();
      await t.tap(_submit);
      await t.pump();
      expect(find.text('Cannot exceed Rs. 5,000'), findsOneWidget);
      expect(env.repo.corrections, isEmpty);
    });

    testWidgets('a valid correction is recorded once with the reason; 0 cancels the payment', (t) async {
      final env = await openCorrect(t);
      await t.enterText(_fields.first, '0');
      await t.enterText(_fields.last, '  Entered  by mistake ');
      await t.pump();
      await t.tap(_submit);
      await t.pumpAndSettle();
      expect(env.repo.corrections.single, (parcelId: 'a', paymentId: 'pay-1', amount: 0, reason: 'Entered by mistake'));
      expect(env.results, [true]);
    });

    for (final size in const [Size(320, 568), Size(393, 852), Size(640, 300)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await openCorrect(t, size: size, scale: scale);
          await t.ensureVisible(_submit);
          await t.tap(_submit);
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
