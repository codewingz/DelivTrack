import 'package:flutter/material.dart';

import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/app_form_sheet.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../utils/text.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/payment.dart';

String? _maxLength(String? value, int max) =>
    collapseSpaces(value ?? '').length > max
    ? 'Use at most $max characters'
    : null;

/// Mark Returned: the returned date (today unless corrected) and an optional reason.
Future<bool> showReturnSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel, {
  Clock clock = const Clock(),
}) => showFormSheet(
  context,
  (_) => _ReturnSheet(
    repository: repository,
    parcel: parcel,
    today: pakistanDate(clock.nowUtc()),
  ),
);

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({
    required this.repository,
    required this.parcel,
    required this.today,
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final String today;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _reason = TextEditingController();
  late String? _date = widget.today;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final hasMoney = parcel.receivedPaisa > 0 || parcel.outstandingPaisa > 0;
    return AppFormSheet(
      title: 'Mark as returned',
      subtitle: hasMoney
          ? '${parcel.orderNumber} · Received ${formatRupees(parcel.receivedPaisa)}, outstanding ${formatRupees(parcel.outstandingPaisa)}. '
                'Nothing is refunded automatically; the parcel is flagged for payment review.'
          : parcel.orderNumber,
      submitLabel: 'Mark Returned',
      onSubmit: () {
        if (_date == null) throw const AppFailure('Select the returned date.');
        return widget.repository.markReturned(
          parcel.id,
          date: _date!,
          reason: _reason.text,
        );
      },
      fields: (busy) => [
        AppDateField(
          label: 'Returned date',
          value: _date,
          enabled: !busy,
          firstDate: parcel.sendingDate,
          lastDate: widget.today,
          onChanged: (date) => setState(() => _date = date),
        ),
        AppTextField.multiline(
          controller: _reason,
          label: 'Reason',
          hint: 'Optional',
          minLines: 2,
          maxLines: 4,
          enabled: !busy,
          validator: (value) => _maxLength(value, 200),
        ),
      ],
    );
  }
}

/// Mark Review Completed: how the payment review was settled, a required note and the date. It only
/// records the decision; nothing is refunded or changed in the payment history.
Future<bool> showReviewSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel, {
  Clock clock = const Clock(),
}) => showFormSheet(
  context,
  (_) => _ReviewSheet(
    repository: repository,
    parcel: parcel,
    today: pakistanDate(clock.nowUtc()),
  ),
);

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.repository,
    required this.parcel,
    required this.today,
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final String today;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _note = TextEditingController();
  ReviewResolution? _resolution;
  late String? _date = widget.today;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    return AppFormSheet(
      title: 'Complete payment review',
      subtitle:
          '${parcel.orderNumber} · Received ${formatRupees(parcel.receivedPaisa)}, outstanding ${formatRupees(parcel.outstandingPaisa)}. '
          'This only records your decision. Nothing is refunded or changed in the payment history.',
      submitLabel: 'Mark Review Completed',
      onSubmit: () {
        if (_resolution == null) {
          throw const AppFailure('Select how the review was settled.');
        }
        if (_date == null) throw const AppFailure('Select the date.');
        return widget.repository.completePaymentReview(
          parcel.id,
          resolution: _resolution!,
          note: _note.text,
          date: _date!,
        );
      },
      fields: (busy) => [
        AppChoiceField<ReviewResolution>(
          label: 'How was it settled?',
          isRequired: true,
          enabled: !busy,
          initialValue: _resolution,
          options: [
            for (final resolution in ReviewResolution.values)
              (value: resolution, label: resolution.label),
          ],
          onChanged: (resolution) => setState(() => _resolution = resolution),
          validator: (resolution) =>
              resolution == null ? 'Select how the review was settled' : null,
        ),
        AppDateField(
          label: 'Date',
          value: _date,
          enabled: !busy,
          firstDate: parcel.returnedDate ?? parcel.sendingDate,
          lastDate: widget.today,
          onChanged: (date) => setState(() => _date = date),
        ),
        AppTextField.multiline(
          controller: _note,
          label: 'Note',
          hint: 'For example: refund of Rs. 1,000 sent by bank transfer',
          isRequired: true,
          minLines: 2,
          maxLines: 4,
          enabled: !busy,
          validator: (value) {
            final length = collapseSpaces(value ?? '').length;
            if (length < 5) return 'Write at least 5 characters';
            return length > 200 ? 'Use at most 200 characters' : null;
          },
        ),
      ],
    );
  }
}

/// Edit Notes: up to 500 characters; saving an empty note removes it.
Future<bool> showNotesSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel,
) => showFormSheet(
  context,
  (_) => _NotesSheet(repository: repository, parcel: parcel),
);

class _NotesSheet extends StatefulWidget {
  const _NotesSheet({required this.repository, required this.parcel});
  final ParcelRepository repository;
  final Parcel parcel;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final _notes = TextEditingController(text: widget.parcel.notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Notes',
      subtitle: widget.parcel.orderNumber,
      submitLabel: 'Save Notes',
      onSubmit: () => widget.repository.setNotes(widget.parcel.id, _notes.text),
      fields: (busy) => [
        AppTextField.multiline(
          controller: _notes,
          label: 'Notes',
          hint: 'Anything worth remembering about this parcel',
          minLines: 3,
          maxLines: 6,
          enabled: !busy,
          validator: (value) => (value?.trim().length ?? 0) > 500
              ? 'Use at most 500 characters'
              : null,
        ),
      ],
    );
  }
}

/// Change or clear a Pay Later parcel's estimated payment date.
Future<bool> showPayLaterDateSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel, {
  Clock clock = const Clock(),
}) => showFormSheet(
  context,
  (_) => _PayLaterDateSheet(
    repository: repository,
    parcel: parcel,
    today: pakistanDate(clock.nowUtc()),
  ),
);

class _PayLaterDateSheet extends StatefulWidget {
  const _PayLaterDateSheet({
    required this.repository,
    required this.parcel,
    required this.today,
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final String today;

  @override
  State<_PayLaterDateSheet> createState() => _PayLaterDateSheetState();
}

class _PayLaterDateSheetState extends State<_PayLaterDateSheet> {
  late String? _date = widget.parcel.estimatedPaymentDate;

  @override
  Widget build(BuildContext context) {
    return AppFormSheet(
      title: 'Pay Later date',
      subtitle:
          '${widget.parcel.orderNumber} · Outstanding ${formatRupees(widget.parcel.outstandingPaisa)}',
      submitLabel: _date == null ? 'Clear Date' : 'Save Date',
      onSubmit: () =>
          widget.repository.setPayLaterDate(widget.parcel.id, _date),
      fields: (busy) => [
        AppDateField(
          label: 'Estimated payment date',
          hint: 'No date set',
          value: _date,
          enabled: !busy,
          firstDate: widget.today,
          lastDate:
              '${int.parse(widget.today.substring(0, 4)) + 5}${widget.today.substring(4)}',
          onChanged: (date) => setState(() => _date = date),
        ),
      ],
    );
  }
}

/// Correct a payment: the payment is cancelled by a reversal and (if the corrected amount is above 0)
/// replaced, so the history keeps both. A reason is required.
Future<bool> showCorrectPaymentSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel,
  Payment payment, {
  Clock clock = const Clock(),
}) => showFormSheet(
  context,
  (_) => _CorrectPaymentSheet(
    repository: repository,
    parcel: parcel,
    payment: payment,
    today: pakistanDate(clock.nowUtc()),
  ),
);

class _CorrectPaymentSheet extends StatefulWidget {
  const _CorrectPaymentSheet({
    required this.repository,
    required this.parcel,
    required this.payment,
    required this.today,
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final Payment payment;
  final String today;

  @override
  State<_CorrectPaymentSheet> createState() => _CorrectPaymentSheetState();
}

class _CorrectPaymentSheetState extends State<_CorrectPaymentSheet> {
  late final _amount = TextEditingController(
    text: plainRupees(widget.payment.amountPaisa),
  );
  final _reason = TextEditingController();
  late String? _date = pakistanDate(widget.payment.receivedAt);

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    // What the parcel could receive in place of this payment.
    final room =
        widget.parcel.expectedPaisa -
        (widget.parcel.receivedPaisa - payment.amountPaisa);
    return AppFormSheet(
      title: 'Correct payment',
      subtitle:
          '${formatDate(pakistanDate(payment.receivedAt))} · ${payment.type.label} · ${formatRupees(payment.amountPaisa)}. '
          'The original stays in the history. Change the amount, the date or both; enter 0 to cancel it.',
      submitLabel: 'Save Correction',
      onSubmit: () {
        final amount = parseRupeesToPaisa(_amount.text)!;
        final originalDate = pakistanDate(payment.receivedAt);
        if (amount > 0 && _date == null) {
          throw const AppFailure('Select the received date.');
        }
        return widget.repository.correctPayment(
          widget.parcel.id,
          payment.id,
          correctedAmountPaisa: amount,
          reason: _reason.text,
          // only sent when it changed, so an amount-only correction keeps the original date
          receivedOn: _date == originalDate ? null : _date,
        );
      },
      fields: (busy) => [
        AppTextField.amount(
          controller: _amount,
          label: 'Corrected amount (Rs.)',
          enabled: !busy,
          validator: (value) {
            final paisa = parseRupeesToPaisa(value ?? '');
            if (paisa == null) return null;
            if (paisa == payment.amountPaisa &&
                _date == pakistanDate(payment.receivedAt)) {
              return 'Change the amount or the date';
            }
            return paisa > room ? 'Cannot exceed ${formatRupees(room)}' : null;
          },
        ),
        AppDateField(
          label: 'Received on',
          value: _date,
          enabled: !busy,
          firstDate: widget.parcel.sendingDate,
          lastDate: widget.today,
          onChanged: (date) => setState(() => _date = date),
        ),
        AppTextField.multiline(
          controller: _reason,
          label: 'Reason for the correction',
          hint: 'Required',
          isRequired: true,
          minLines: 2,
          maxLines: 4,
          enabled: !busy,
          validator: (value) {
            final length = collapseSpaces(value ?? '').length;
            if (length < 5) return 'Give a reason (at least 5 characters)';
            return length > 200 ? 'Use at most 200 characters' : null;
          },
        ),
      ],
    );
  }
}
