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
import '../domain/payment.dart';
import '../domain/payment_rules.dart';

/// Opens the "Mark Payment Received" sheet. Returns true when a payment was recorded.
Future<bool> showPaymentSheet(
  BuildContext context,
  ParcelRepository repository,
  Parcel parcel,
) => showFormSheet(
  context,
  (_) => PaymentSheet(repository: repository, parcel: parcel),
);

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.repository,
    required this.parcel,
    this.clock = const Clock(),
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final Clock clock;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late final _amount = TextEditingController(
    text: plainRupees(widget.parcel.outstandingPaisa),
  );
  final _note = TextEditingController();
  PaymentType? _type;
  bool _enteredLate = false;
  String? _receivedOn;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.parcel.outstandingPaisa;
    final today = pakistanDate(widget.clock.nowUtc());
    return AppFormSheet(
      title: 'Mark payment received',
      subtitle:
          '${widget.parcel.orderNumber} · Outstanding ${formatRupees(outstanding)}',
      submitLabel: 'Confirm Payment',
      onSubmit: () {
        if (_enteredLate && _receivedOn == null) {
          throw const AppFailure('Select the day it was received.');
        }
        return widget.repository.recordPayment(
          widget.parcel.id,
          amountPaisa: parseRupeesToPaisa(_amount.text)!,
          type: _type!,
          note: _note.text,
          receivedOn: _enteredLate ? _receivedOn : null,
        );
      },
      fields: (busy) => [
        AppTextField.amount(
          controller: _amount,
          label: 'Amount received (Rs.)',
          minPaisa: 1,
          enabled: !busy,
          validator: (value) {
            final paisa = parseRupeesToPaisa(value ?? '');
            return paisa != null && paisa > outstanding
                ? 'Cannot exceed outstanding ${formatRupees(outstanding)}'
                : null;
          },
        ),
        AppChoiceField<PaymentType>(
          label: 'Payment type',
          isRequired: true,
          enabled: !busy,
          initialValue: _type,
          options: [
            for (final type in PaymentType.values)
              (value: type, label: type.label),
          ],
          onChanged: (type) => setState(() => _type = type),
          validator: (type) => type == null ? 'Select a payment type' : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Entered late?'),
          subtitle: const Text('The payment was received on an earlier day'),
          value: _enteredLate,
          onChanged: busy
              ? null
              : (value) => setState(() => _enteredLate = value),
        ),
        if (_enteredLate)
          AppDateField(
            label: 'Received on',
            hint: 'Select the day it was received',
            value: _receivedOn,
            enabled: !busy,
            firstDate: widget.parcel.sendingDate,
            lastDate: today,
            onChanged: (date) => setState(() => _receivedOn = date),
          ),
        AppTextField.multiline(
          controller: _note,
          label: 'Note',
          hint: 'Optional',
          minLines: 2,
          maxLines: 4,
          enabled: !busy,
          validator: (value) =>
              collapseSpaces(value ?? '').length > maxPaymentNoteLength
              ? 'Use at most $maxPaymentNoteLength characters'
              : null,
        ),
      ],
    );
  }
}
