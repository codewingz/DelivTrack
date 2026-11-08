import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../parcels/domain/payment.dart';
import '../../products/domain/product.dart';

enum ReportType {
  outstanding(
    'Outstanding payments',
    'Unpaid and part-paid parcels with what is still due',
    'Sending date',
  ),
  paymentHistory(
    'Payment received history',
    'Every payment received, newest first',
    'Received date',
  ),
  returned(
    'Returned parcels',
    'Parcels sent back, with the reason and review flag',
    'Returned date',
  ),
  freeGift(
    'Gift / Free parcels',
    'Parcels sent without payment, with their delivery charges',
    'Sending date',
  ),
  payLater(
    'Pay Later balances',
    'What Pay Later customers still owe, and what is overdue',
    'Pay Later date',
  ),
  productWise(
    'Product-wise parcels',
    'How many parcels and how much of each product',
    'Sending date',
  ),
  dateWise('Date-wise parcels', 'Parcels sent on each day', 'Sending date');

  const ReportType(this.title, this.description, this.dateLabel);
  final String title;
  final String description;

  /// Which date the From / To range applies to.
  final String dateLabel;

  /// Only the payment history needs the individual payments.
  bool get needsPayments => this == paymentHistory;

  static ReportType? byName(String name) =>
      values.where((type) => type.name == name).firstOrNull;
}

/// One line of a report. [parcelId] makes the row open that parcel.
class ReportRow {
  const ReportRow({
    required this.title,
    required this.lines,
    this.trailing,
    this.parcelId,
    this.urgent = false,
  });
  final String title;
  final List<String> lines;
  final String? trailing;
  final String? parcelId;
  final bool urgent;
}

class ReportResult {
  const ReportResult({required this.rows, required this.totals});
  final List<ReportRow> rows;

  /// The totals shown pinned under the list.
  final List<String> totals;
}

bool _inRange(String? date, String? from, String? to) {
  if (from == null && to == null) return true;
  if (date == null) return false;
  return (from == null || date.compareTo(from) >= 0) &&
      (to == null || date.compareTo(to) <= 0);
}

String _plural(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';

String _sent(Parcel parcel) =>
    'Sent ${parcel.sendingDateLabel} · ${parcel.method.label}';

String _reference(Parcel parcel) => parcel.postalReference.isEmpty
    ? 'No postal reference yet'
    : '${parcel.serviceLabel} · ${parcel.postalReference}';

String _title(Parcel parcel) =>
    '${parcel.orderNumber} · ${parcel.customerName}';

/// Builds [type] for [parcels] (every parcel of the user), limited to the From / To dates (either may
/// be null). [payments] are each parcel's payments, needed only for the payment history.
ReportResult buildReport(
  ReportType type,
  List<Parcel> parcels, {
  Map<String, List<Payment>> payments = const {},
  String? from,
  String? to,
  required String today,
}) {
  final newestFirst = [...parcels]
    ..sort((a, b) => b.orderSequence.compareTo(a.orderSequence));
  switch (type) {
    case ReportType.outstanding:
      final shown = [
        for (final parcel in newestFirst)
          if (parcel.method != CollectionMethod.giftFree &&
              parcel.status != ParcelStatus.returned &&
              parcel.outstandingPaisa > 0 &&
              _inRange(parcel.sendingDate, from, to))
            parcel,
      ];
      return ReportResult(
        rows: [
          for (final parcel in shown)
            ReportRow(
              title: _title(parcel),
              lines: [
                _reference(parcel),
                _sent(parcel),
                if (parcel.estimatedPaymentDate != null)
                  'Estimated payment date ${formatDate(parcel.estimatedPaymentDate!)}',
                'Expected ${formatRupees(parcel.expectedPaisa)} · Received ${formatRupees(parcel.receivedPaisa)}',
              ],
              trailing: formatRupees(parcel.outstandingPaisa),
              parcelId: parcel.id,
            ),
        ],
        totals: [
          'Total outstanding ${formatRupees(shown.fold(0, (sum, p) => sum + p.outstandingPaisa))}',
          _plural(shown.length, 'parcel', 'parcels'),
        ],
      );

    case ReportType.paymentHistory:
      final entries = <({Parcel parcel, Payment payment})>[
        for (final parcel in newestFirst)
          for (final payment in payments[parcel.id] ?? const <Payment>[])
            if (_inRange(pakistanDate(payment.receivedAt), from, to))
              (parcel: parcel, payment: payment),
      ]..sort((a, b) => b.payment.receivedAt.compareTo(a.payment.receivedAt));
      return ReportResult(
        rows: [
          for (final (:parcel, :payment) in entries)
            ReportRow(
              title: _title(parcel),
              lines: [
                '${formatDate(pakistanDate(payment.receivedAt))} · ${payment.type.label}${payment.isReversal ? ' · Reversal: ${payment.correctionReason}' : ''}${payment.correctionOfPaymentId != null ? ' · Correction' : ''}',
                if (payment.note != null) payment.note!,
              ],
              trailing: formatRupees(payment.amountPaisa),
              parcelId: parcel.id,
              urgent: payment.isReversal,
            ),
        ],
        totals: [
          'Total received ${formatRupees(entries.fold(0, (sum, e) => sum + e.payment.amountPaisa))}',
          _plural(entries.length, 'payment', 'payments'),
        ],
      );

    case ReportType.returned:
      final shown = [
        for (final parcel in newestFirst)
          if (parcel.status == ParcelStatus.returned &&
              _inRange(parcel.returnedDate, from, to))
            parcel,
      ];
      return ReportResult(
        rows: [
          for (final parcel in shown)
            ReportRow(
              title: _title(parcel),
              lines: [
                'Returned ${parcel.returnedDate == null ? '' : formatDate(parcel.returnedDate!)}',
                'Reason: ${parcel.returnReason ?? 'Not given'}',
                if (parcel.paymentReviewRequired)
                  'Requires payment review · Received ${formatRupees(parcel.receivedPaisa)}, outstanding ${formatRupees(parcel.outstandingPaisa)}',
              ],
              parcelId: parcel.id,
              urgent: parcel.paymentReviewRequired,
            ),
        ],
        totals: [
          _plural(shown.length, 'returned parcel', 'returned parcels'),
          '${shown.where((p) => p.paymentReviewRequired).length} need payment review',
        ],
      );

    case ReportType.freeGift:
      final shown = [
        for (final parcel in newestFirst)
          if (parcel.method == CollectionMethod.giftFree &&
              _inRange(parcel.sendingDate, from, to))
            parcel,
      ];
      return ReportResult(
        rows: [
          for (final parcel in shown)
            ReportRow(
              title: _title(parcel),
              lines: [
                parcel.items
                    .map((item) => '${item.productName} × ${item.amountLabel}')
                    .join(', '),
                _sent(parcel),
                'Delivery charges ${parcel.deliveryChargePaisa == null ? 'not entered yet' : formatRupees(parcel.deliveryChargePaisa!)}',
              ],
              parcelId: parcel.id,
            ),
        ],
        totals: [
          _plural(shown.length, 'parcel', 'parcels'),
          'Total delivery charges ${formatRupees(shown.fold(0, (sum, p) => sum + (p.deliveryChargePaisa ?? 0)))}',
        ],
      );

    case ReportType.payLater:
      final shown =
          [
            for (final parcel in newestFirst)
              if (parcel.method == CollectionMethod.payLater &&
                  parcel.status != ParcelStatus.returned &&
                  parcel.outstandingPaisa > 0 &&
                  _inRange(parcel.estimatedPaymentDate, from, to))
                parcel,
          ]..sort(
            (a, b) => (a.estimatedPaymentDate ?? '9999').compareTo(
              b.estimatedPaymentDate ?? '9999',
            ),
          );
      bool overdue(Parcel p) =>
          p.estimatedPaymentDate != null &&
          p.estimatedPaymentDate!.compareTo(today) < 0;
      return ReportResult(
        rows: [
          for (final parcel in shown)
            ReportRow(
              title: _title(parcel),
              lines: [
                parcel.estimatedPaymentDate == null
                    ? 'No date set'
                    : 'Pay Later date ${formatDate(parcel.estimatedPaymentDate!)}${overdue(parcel) ? ' · Overdue' : ''}',
                'Expected ${formatRupees(parcel.expectedPaisa)} · Received ${formatRupees(parcel.receivedPaisa)}',
              ],
              trailing: formatRupees(parcel.outstandingPaisa),
              parcelId: parcel.id,
              urgent: overdue(parcel),
            ),
        ],
        totals: [
          'Total balance ${formatRupees(shown.fold(0, (sum, p) => sum + p.outstandingPaisa))}',
          'Overdue ${formatRupees(shown.where(overdue).fold(0, (sum, p) => sum + p.outstandingPaisa))}',
        ],
      );

    case ReportType.productWise:
      final inRange = [
        for (final parcel in newestFirst)
          if (_inRange(parcel.sendingDate, from, to)) parcel,
      ];
      final byProduct =
          <
            String,
            ({String name, Set<String> parcelIds, Map<SaleUnit, int> amounts})
          >{};
      for (final parcel in inRange) {
        for (final item in parcel.items) {
          final current =
              byProduct[item.productId] ??
              (
                name: item.productName,
                parcelIds: <String>{},
                amounts: <SaleUnit, int>{},
              );
          // Whole count for counted units, thousandths for kg / litres.
          final amount = item.saleUnit.isMeasured
              ? item.weightGrams ?? 0
              : item.quantity ?? 0;
          byProduct[item.productId] = (
            name: current.name,
            parcelIds: {...current.parcelIds, parcel.id},
            amounts: {
              ...current.amounts,
              item.saleUnit: (current.amounts[item.saleUnit] ?? 0) + amount,
            },
          );
        }
      }
      final entries = byProduct.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return ReportResult(
        rows: [
          for (final entry in entries)
            ReportRow(
              title: entry.name,
              lines: [
                _plural(entry.parcelIds.length, 'parcel', 'parcels'),
                [
                  // In dropdown order, so pieces come before kg, then the rest.
                  for (final unit in SaleUnit.values)
                    if ((entry.amounts[unit] ?? 0) > 0)
                      unit.isMeasured
                          ? formatMeasure(
                              entry.amounts[unit]!,
                              entry.amounts[unit] == 1000
                                  ? unit.singular
                                  : unit.plural,
                            )
                          : _plural(
                              entry.amounts[unit]!,
                              unit.singular,
                              unit.plural,
                            ),
                ].join(' · '),
              ],
            ),
        ],
        totals: [
          _plural(entries.length, 'product', 'products'),
          _plural(inRange.length, 'parcel', 'parcels'),
        ],
      );

    case ReportType.dateWise:
      final byDate = <String, int>{};
      for (final parcel in newestFirst) {
        if (_inRange(parcel.sendingDate, from, to)) {
          byDate[parcel.sendingDate] = (byDate[parcel.sendingDate] ?? 0) + 1;
        }
      }
      final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
      return ReportResult(
        rows: [
          for (final date in dates)
            ReportRow(
              title: formatDate(date),
              lines: [_plural(byDate[date]!, 'parcel', 'parcels')],
            ),
        ],
        totals: [
          _plural(dates.length, 'day', 'days'),
          _plural(byDate.values.fold(0, (a, b) => a + b), 'parcel', 'parcels'),
        ],
      );
  }
}
