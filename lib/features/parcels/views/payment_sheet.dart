import 'package:flutter/material.dart';
import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/text.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/payment.dart';
import '../domain/payment_rules.dart';

/// Opens the "Mark Payment Received" sheet. Returns true when a payment was recorded.
Future<bool> showPaymentSheet(BuildContext context, ParcelRepository repository, Parcel parcel) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => PaymentSheet(repository: repository, parcel: parcel),
  );
  return saved ?? false;
}

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.repository, required this.parcel});
  final ParcelRepository repository;
  final Parcel parcel;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: plainRupees(widget.parcel.outstandingPaisa));
  final _note = TextEditingController();
  final _viewModel = ActionViewModel();
  PaymentType? _type;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseRupeesToPaisa(_amount.text)!;
    final type = _type!;
    final saved = await _viewModel.run(
      () => widget.repository.recordPayment(widget.parcel.id, amountPaisa: amount, type: type, note: _note.text),
    );
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.parcel.outstandingPaisa;
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mark payment received',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${widget.parcel.orderNumber} · Outstanding ${formatRupees(outstanding)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField.amount(
                  controller: _amount,
                  label: 'Amount received (Rs.)',
                  minPaisa: 1,
                  enabled: !busy,
                  validator: (value) {
                    final paisa = parseRupeesToPaisa(value ?? '');
                    return paisa != null && paisa > outstanding ? 'Cannot exceed outstanding ${formatRupees(outstanding)}' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppChoiceField<PaymentType>(
                  label: 'Payment type',
                  isRequired: true,
                  enabled: !busy,
                  initialValue: _type,
                  options: [for (final type in PaymentType.values) (value: type, label: type.label)],
                  onChanged: (type) => setState(() => _type = type),
                  validator: (type) => type == null ? 'Select a payment type' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField.multiline(
                  controller: _note,
                  label: 'Note',
                  hint: 'Optional',
                  minLines: 2,
                  maxLines: 4,
                  enabled: !busy,
                  validator: (value) => collapseSpaces(value ?? '').length > maxPaymentNoteLength ? 'Use at most $maxPaymentNoteLength characters' : null,
                ),
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(label: 'Confirm Payment', isLoading: busy, onPressed: _save),
              ],
            ),
          ),
        );
      },
    );
  }
}
