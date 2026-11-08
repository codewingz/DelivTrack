import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/payments/domain/payment_tabs.dart';
import 'package:deliv_track/features/reports/domain/reports.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

ReportResult _build(
  ReportType type,
  List<Parcel> parcels, {
  Map<String, List<Payment>> payments = const {},
  String? from,
  String? to,
}) => buildReport(
  type,
  parcels,
  payments: payments,
  from: from,
  to: to,
  today: _today,
);

Payment _pay(
  String id,
  int amount,
  DateTime when, {
  PaymentType type = PaymentType.advance,
  String? note,
  String? reversalOf,
  String? reason,
  String? correctionOf,
}) => Payment(
  id: id,
  amountPaisa: amount,
  type: type,
  note: note,
  receivedAt: when,
  reversalOfPaymentId: reversalOf,
  correctionReason: reason,
  correctionOfPaymentId: correctionOf,
);

void main() {
  group('Outstanding payments', () {
    final parcels = [
      testParcel(
        id: 'a',
        sequence: 1,
        customerName: 'Ali',
        sendingDate: '2026-11-01',
      ), // owes 5,000
      testParcel(
        id: 'b',
        sequence: 2,
        customerName: 'Sara',
        sendingDate: '2026-11-05',
        received: 200000,
        method: CollectionMethod.payLater,
        payDate: '2026-12-01',
      ), // owes 3,000
      testParcel(id: 'c', sequence: 3, customerName: 'Paid', received: 500000),
      testParcel(
        id: 'd',
        sequence: 4,
        customerName: 'Gift',
        method: CollectionMethod.giftFree,
      ),
      testParcel(
        id: 'e',
        sequence: 5,
        customerName: 'Back',
        status: ParcelStatus.returned,
        paymentReviewRequired: true,
      ),
    ];

    test('lists unpaid and part-paid parcels (not paid, Free or returned) with every column and the total', () {
      final r = _build(ReportType.outstanding, parcels);
      expect(r.rows.map((row) => row.parcelId), [
        'b',
        'a',
      ], reason: 'newest first');
      final b = r.rows.first;
      expect(b.title, 'ADT-000002 · Sara');
      expect(b.lines, contains('VPP · VPP 12345'));
      expect(b.lines, contains('Sent 5 Nov 2026 · Pay Later'));
      expect(b.lines, contains('Estimated payment date 1 Dec 2026'));
      expect(b.lines, contains('Expected Rs. 5,000 · Received Rs. 2,000'));
      expect(b.trailing, 'Rs. 3,000');
      expect(r.totals, ['Total outstanding Rs. 8,000', '2 parcels']);
    });

    test('the date range limits it by sending date, both ends included', () {
      expect(
        _build(
          ReportType.outstanding,
          parcels,
          from: '2026-11-02',
        ).rows.map((r) => r.parcelId),
        ['b'],
      );
      expect(
        _build(
          ReportType.outstanding,
          parcels,
          to: '2026-11-01',
        ).rows.map((r) => r.parcelId),
        ['a'],
      );
      expect(
        _build(
          ReportType.outstanding,
          parcels,
          from: '2026-11-05',
          to: '2026-11-05',
        ).rows.map((r) => r.parcelId),
        ['b'],
      );
      expect(
        _build(ReportType.outstanding, parcels, from: '2027-01-01').rows,
        isEmpty,
      );
    });

    test(
      'the total equals the Payments screen\'s Outstanding total (AT-24)',
      () {
        final report = _build(ReportType.outstanding, parcels);
        final fromRows = report.rows.fold(
          0,
          (sum, row) =>
              sum +
              parcels.firstWhere((p) => p.id == row.parcelId).outstandingPaisa,
        );
        expect(fromRows, PaymentTotals.from(parcels).outstandingPaisa);
      },
    );
  });

  group('Payment received history', () {
    final parcels = [
      testParcel(id: 'a', sequence: 1, customerName: 'Ali'),
      testParcel(id: 'b', sequence: 2, customerName: 'Sara'),
    ];
    final payments = {
      'a': [
        _pay(
          'a2',
          150000,
          DateTime.utc(2026, 11, 9, 6),
          type: PaymentType.customerPayment,
          note: 'second',
        ),
        _pay('a1', 100000, DateTime.utc(2026, 11, 1, 6)),
      ],
      'b': [
        _pay(
          'rev_b1',
          -200000,
          DateTime.utc(2026, 11, 8, 6),
          reversalOf: 'b1',
          reason: 'Wrong amount',
        ),
        _pay('b1', 200000, DateTime.utc(2026, 11, 7, 6)),
      ],
    };

    test('every payment newest first with date, type, note; reversals negative and flagged; net total', () {
      final r = _build(ReportType.paymentHistory, parcels, payments: payments);
      expect(r.rows.map((row) => row.trailing), [
        'Rs. 1,500',
        '-Rs. 2,000',
        'Rs. 2,000',
        'Rs. 1,000',
      ]);
      expect(r.rows.first.lines, ['9 Nov 2026 · Customer payment', 'second']);
      expect(
        r.rows[1].lines.single,
        '8 Nov 2026 · Advance · Reversal: Wrong amount',
      );
      expect(r.rows[1].urgent, isTrue);
      expect(r.totals, [
        'Total received Rs. 2,500',
        '4 payments',
      ], reason: '1,500 - 2,000 + 2,000 + 1,000');
    });

    test('the range applies to the received date', () {
      final r = _build(
        ReportType.paymentHistory,
        parcels,
        payments: payments,
        from: '2026-11-08',
        to: '2026-11-09',
      );
      expect(r.rows.map((row) => row.trailing), ['Rs. 1,500', '-Rs. 2,000']);
      expect(r.totals.first, 'Total received -Rs. 500');
    });

    test(
      'parcels without payments add nothing; an empty history has zero totals',
      () {
        final r = _build(ReportType.paymentHistory, parcels);
        expect(r.rows, isEmpty);
        expect(r.totals, ['Total received Rs. 0', '0 payments']);
      },
    );
  });

  test('Returned parcels: date, reason, review flag; counts; range by returned date', () {
    final parcels = [
      testParcel(
        id: 'a',
        sequence: 1,
        customerName: 'Ali',
        status: ParcelStatus.returned,
        returnedDate: '2026-11-08',
        returnReason: 'Refused',
        paymentReviewRequired: true,
        received: 100000,
      ),
      testParcel(
        id: 'b',
        sequence: 2,
        customerName: 'Gift',
        method: CollectionMethod.giftFree,
        status: ParcelStatus.returned,
        returnedDate: '2026-11-02',
      ),
      testParcel(id: 'c', sequence: 3),
    ];
    final r = _build(ReportType.returned, parcels);
    expect(r.rows.map((row) => row.parcelId), ['b', 'a']);
    expect(r.rows.last.lines, [
      'Returned 8 Nov 2026',
      'Reason: Refused',
      'Requires payment review · Received Rs. 1,000, outstanding Rs. 4,000',
    ]);
    expect(r.rows.last.urgent, isTrue);
    expect(r.rows.first.lines[1], 'Reason: Not given');
    expect(r.totals, ['2 returned parcels', '1 need payment review']);
    expect(
      _build(
        ReportType.returned,
        parcels,
        from: '2026-11-05',
      ).rows.map((row) => row.parcelId),
      ['a'],
    );
  });

  test('Gift / Free parcels: products, delivery charge, counts and the charges total', () {
    final parcels = [
      testParcel(
        id: 'a',
        sequence: 1,
        customerName: 'Gift One',
        method: CollectionMethod.giftFree,
        charge: 20000,
        items: [
          ParcelItem.pieces(
            productId: 'p1',
            productName: 'Mango Box',
            quantity: 3,
            unitPricePaisa: 0,
          ),
        ],
      ),
      testParcel(
        id: 'b',
        sequence: 2,
        customerName: 'Gift Two',
        method: CollectionMethod.giftFree,
        reference: '',
        charge: null,
        status: ParcelStatus.draft,
      ),
      testParcel(id: 'c', sequence: 3),
    ];
    final r = _build(ReportType.freeGift, parcels);
    expect(r.rows.map((row) => row.parcelId), ['b', 'a']);
    expect(r.rows.last.lines.first, 'Mango Box × 3 pieces');
    expect(r.rows.last.lines.last, 'Delivery charges Rs. 200');
    expect(r.rows.first.lines.last, 'Delivery charges not entered yet');
    expect(r.totals, ['2 parcels', 'Total delivery charges Rs. 200']);
  });

  group('Pay Later balances', () {
    final parcels = [
      testParcel(
        id: 'a',
        sequence: 1,
        customerName: 'Overdue',
        method: CollectionMethod.payLater,
        payDate: '2026-11-01',
      ), // 5,000
      testParcel(
        id: 'b',
        sequence: 2,
        customerName: 'Upcoming',
        method: CollectionMethod.payLater,
        payDate: '2026-12-01',
        received: 100000,
      ), // 4,000
      testParcel(
        id: 'c',
        sequence: 3,
        customerName: 'Undated',
        method: CollectionMethod.payLater,
      ),
      testParcel(
        id: 'd',
        sequence: 4,
        customerName: 'Paid',
        method: CollectionMethod.payLater,
        received: 500000,
      ),
      testParcel(id: 'e', sequence: 5, customerName: 'Other'),
    ];

    test('dated first by date, undated last; overdue flagged; balance and overdue totals', () {
      final r = _build(ReportType.payLater, parcels);
      expect(r.rows.map((row) => row.parcelId), ['a', 'b', 'c']);
      expect(r.rows.first.lines.first, 'Pay Later date 1 Nov 2026 · Overdue');
      expect(r.rows.first.urgent, isTrue);
      expect(r.rows[1].urgent, isFalse);
      expect(r.rows.last.lines.first, 'No date set');
      expect(r.totals, ['Total balance Rs. 14,000', 'Overdue Rs. 5,000']);
    });

    test('a date range leaves out parcels without a date', () {
      final r = _build(
        ReportType.payLater,
        parcels,
        from: '2026-11-01',
        to: '2026-12-31',
      );
      expect(r.rows.map((row) => row.parcelId), ['a', 'b']);
    });
  });

  test(
    'Product-wise: parcels and quantities per product, pieces and kg, by name',
    () {
      final parcels = [
        testParcel(
          id: 'a',
          sequence: 1,
          sendingDate: '2026-11-01',
          items: [
            ParcelItem.pieces(
              productId: 'p1',
              productName: 'Mango Box',
              quantity: 2,
              unitPricePaisa: 100,
            ),
            ParcelItem.weight(
              productId: 'p2',
              productName: 'Dry Fruits',
              weightGrams: 1500,
              unitPricePaisa: 100,
            ),
          ],
        ),
        testParcel(
          id: 'b',
          sequence: 2,
          sendingDate: '2026-11-05',
          items: [
            ParcelItem.pieces(
              productId: 'p1',
              productName: 'Mango Box',
              quantity: 3,
              unitPricePaisa: 100,
            ),
            ParcelItem.weight(
              productId: 'p2',
              productName: 'Dry Fruits',
              weightGrams: 250,
              unitPricePaisa: 100,
            ),
          ],
        ),
      ];
      final r = _build(ReportType.productWise, parcels);
      expect(r.rows.map((row) => row.title), ['Dry Fruits', 'Mango Box']);
      expect(r.rows[0].lines, ['2 parcels', '1.75 kg']);
      expect(r.rows[1].lines, ['2 parcels', '5 pieces']);
      expect(r.totals, ['2 products', '2 parcels']);
      expect(
        _build(
          ReportType.productWise,
          parcels,
          from: '2026-11-03',
        ).rows.map((row) => row.lines.first),
        ['1 parcel', '1 parcel'],
      );
    },
  );

  test('Date-wise: parcels per sending day, newest day first', () {
    final parcels = [
      testParcel(id: 'a', sequence: 1, sendingDate: '2026-11-01'),
      testParcel(id: 'b', sequence: 2, sendingDate: '2026-11-05'),
      testParcel(id: 'c', sequence: 3, sendingDate: '2026-11-05'),
    ];
    final r = _build(ReportType.dateWise, parcels);
    expect(r.rows.map((row) => '${row.title}: ${row.lines.single}'), [
      '5 Nov 2026: 2 parcels',
      '1 Nov 2026: 1 parcel',
    ]);
    expect(r.totals, ['2 days', '3 parcels']);
    expect(_build(ReportType.dateWise, const []).totals, [
      '0 days',
      '0 parcels',
    ]);
  });

  test('every report copes with no parcels at all', () {
    for (final type in ReportType.values) {
      final r = _build(type, const []);
      expect(r.rows, isEmpty, reason: type.name);
      expect(r.totals, isNotEmpty, reason: type.name);
    }
  });

  test('report types can be found by name (for the route)', () {
    expect(ReportType.byName('outstanding'), ReportType.outstanding);
    expect(ReportType.byName('nope'), isNull);
    expect(ReportType.paymentHistory.needsPayments, isTrue);
    expect(ReportType.outstanding.needsPayments, isFalse);
  });
}
