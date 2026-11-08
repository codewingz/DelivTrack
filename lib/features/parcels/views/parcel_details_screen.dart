import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/payment.dart';
import 'parcel_action_sheets.dart';
import 'payment_sheet.dart';
import 'parcel_status_chips.dart';

/// One parcel's details with an Edit action. Payment and return actions are added by their own features.
class ParcelDetailsScreen extends StatefulWidget {
  const ParcelDetailsScreen({super.key, required this.repository, required this.parcelId, required this.onEdit});
  final ParcelRepository repository;
  final String parcelId;

  /// Opens the edit form; completes with the parcel id once saved, or null if cancelled.
  final Future<String?> Function(Parcel parcel) onEdit;

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  late Stream<Parcel?> _stream = widget.repository.watch(widget.parcelId);

  Future<void> _edit(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await widget.onEdit(parcel);
    if (saved != null) messenger.showSnackBar(const SnackBar(content: Text('Parcel updated.')));
  }

  /// Opens one of the action sheets; a snackbar confirms when it was submitted.
  Future<void> _act(Future<bool> Function() open, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await open()) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on AppFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _retry() => setState(() => _stream = widget.repository.watch(widget.parcelId));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Parcel?>(
      stream: _stream,
      builder: (context, snapshot) {
        final parcel = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(parcel?.orderNumber ?? 'Parcel'),
            actions: [
              if (parcel != null && parcel.status != ParcelStatus.returned && !parcel.isArchived)
                IconButton(tooltip: 'Edit parcel', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(parcel)),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _body(snapshot, parcel),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Parcel?> snapshot, Parcel? parcel) {
    if (snapshot.hasError) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load this parcel",
        message: snapshot.error is Exception ? snapshot.error.toString() : 'Please try again.',
        actionLabel: 'Retry',
        onAction: _retry,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) return const SingleChildScrollView(child: ListSkeleton());
    if (parcel == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'This parcel was not found');
    return _ParcelView(parcel: parcel, repository: widget.repository, onAction: _act);
  }
}

class _ParcelView extends StatelessWidget {
  const _ParcelView({required this.parcel, required this.repository, required this.onAction});
  final Parcel parcel;
  final ParcelRepository repository;
  final Future<void> Function(Future<bool> Function() open, String done) onAction;

  @override
  Widget build(BuildContext context) {
    final isFree = parcel.method == CollectionMethod.giftFree;
    final isReturned = parcel.status == ParcelStatus.returned;
    final canReceive = !isFree && !isReturned && !parcel.isArchived && parcel.outstandingPaisa > 0;
    final canChangeDate = parcel.method == CollectionMethod.payLater && !isReturned && !parcel.isArchived && parcel.outstandingPaisa > 0;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parcel.isArchived)
            _Section(title: 'Archived', children: [
              const _Info('Status', 'This parcel is archived. It is hidden from the lists and totals, and its order number stays reserved.'),
              PrimaryButton(
                label: 'Restore Parcel',
                onPressed: () => onAction(() async {
                  await repository.restore(parcel.id);
                  return true;
                }, 'Parcel restored.'),
              ),
            ]),
          _Section(title: 'Parcel', children: [
            ParcelStatusChips(status: parcel.status, payment: parcel.paymentStatus, reviewRequired: parcel.paymentReviewRequired),
            _Info('Order number', parcel.orderNumber),
            _Info('Sending date', parcel.sendingDateLabel),
            _Info('Parcel type', parcel.method.label),
          ]),
          _Section(title: 'Customer', children: [
            _Info('Name', parcel.customerName),
            _Info('Phone', parcel.customerPhone),
            _Info('Address', parcel.customerAddress),
          ]),
          _Section(title: 'Products', children: [
            for (final item in parcel.items)
              _Info(
                item.productName,
                isFree ? item.amountLabel : '${item.amountLabel} × ${formatRupees(item.unitPricePaisa)}${item.saleUnit.value == 'per_kg' ? ' per kg' : ' each'} = ${formatRupees(item.lineTotalPaisa)}',
              ),
          ]),
          _Section(title: 'Postal details', children: [
            _Info('Service', parcel.serviceLabel),
            _Info(
              'Postal reference',
              parcel.postalReference.isEmpty ? 'Not entered yet' : parcel.postalReference,
              trailing: parcel.postalReference.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Copy postal reference',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: parcel.postalReference));
                        messenger.showSnackBar(const SnackBar(content: Text('Postal reference copied.')));
                      },
                    ),
            ),
            _Info('Delivery charges', parcel.deliveryChargePaisa == null ? 'Not entered yet' : formatRupees(parcel.deliveryChargePaisa!)),
            if (parcel.packedWeightGrams != null) _Info('Packed parcel weight', formatKg(parcel.packedWeightGrams!)),
          ]),
          _Section(title: 'Payment', children: [
            _Info('Expected amount', isFree ? 'None (Gift / Free)' : formatRupees(parcel.expectedPaisa)),
            _Info('Received', formatRupees(parcel.receivedPaisa)),
            _Info('Outstanding', formatRupees(parcel.outstandingPaisa)),
            if (parcel.estimatedPaymentDate != null) _Info('Estimated payment date', formatDate(parcel.estimatedPaymentDate!)),
            if (canReceive)
              PrimaryButton(
                label: 'Mark Payment Received',
                onPressed: () => onAction(() => showPaymentSheet(context, repository, parcel), 'Payment recorded.'),
              ),
          ]),
          if (!isFree) _PaymentHistory(repository: repository, parcel: parcel, onAction: onAction),
          if (isReturned)
            _Section(title: 'Return', children: [
              if (parcel.returnedDate != null) _Info('Returned on', formatDate(parcel.returnedDate!)),
              _Info('Reason', parcel.returnReason ?? 'Not given'),
              if (parcel.paymentReviewRequired)
                const _Info('Payment review', 'Requires payment review: money was received or is still owed. Nothing is refunded automatically.'),
            ]),
          _Section(title: 'Notes', children: [_Info('Notes', parcel.notes ?? 'No notes yet')]),
          if (!parcel.isArchived)
          _Section(title: 'Actions', children: [
            OutlinedButton(
              onPressed: () => onAction(() => showNotesSheet(context, repository, parcel), 'Notes saved.'),
              child: Text(parcel.notes == null ? 'Add Notes' : 'Edit Notes'),
            ),
            if (canChangeDate)
              OutlinedButton(
                onPressed: () => onAction(() => showPayLaterDateSheet(context, repository, parcel), 'Pay Later date saved.'),
                child: const Text('Change Pay Later Date'),
              ),
            if (parcel.status == ParcelStatus.sent)
              OutlinedButton(
                onPressed: () => onAction(() => showReturnSheet(context, repository, parcel), 'Parcel marked as returned.'),
                child: const Text('Mark Returned'),
              ),
            if (parcel.paymentReviewRequired)
              const _Info('Archive', "This parcel can't be archived until its payment review is completed."),
            if (parcel.canArchive)
              OutlinedButton(
                onPressed: () => onAction(() async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Archive this parcel?',
                    message: 'It will be hidden from the lists and totals. Its order number stays reserved and you can restore it any time.',
                    confirmLabel: 'Archive',
                  );
                  if (!confirmed) return false;
                  await repository.archive(parcel.id);
                  return true;
                }, 'Parcel archived.'),
                child: const Text('Archive Parcel'),
              ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              for (final child in children) ...[const SizedBox(height: AppSpacing.md), child],
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.trailing});
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
    if (trailing == null) return text;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: text), trailing!]);
  }
}

class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({required this.repository, required this.parcel, required this.onAction});
  final ParcelRepository repository;
  final Parcel parcel;
  final Future<void> Function(Future<bool> Function() open, String done) onAction;

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  late final Stream<List<Payment>> _payments = widget.repository.watchPayments(widget.parcel.id);

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    return StreamBuilder<List<Payment>>(
      stream: _payments,
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const <Payment>[];
        final reversed = {for (final p in payments) ?p.reversalOfPaymentId};
        return _Section(title: 'Payment history', children: [
          if (snapshot.hasError)
            const _Info('Payments', "Couldn't load the payments.")
          else if (payments.isEmpty)
            const _Info('Payments', 'No payments received yet')
          else
            for (final payment in payments)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PaymentRow(payment: payment, corrected: reversed.contains(payment.id))),
                  if (payment.amountPaisa > 0 && !reversed.contains(payment.id) && parcel.status != ParcelStatus.returned && !parcel.isArchived)
                    TextButton(
                      onPressed: () => widget.onAction(
                        () => showCorrectPaymentSheet(context, widget.repository, parcel, payment),
                        'Payment corrected.',
                      ),
                      child: const Text('Correct'),
                    ),
                ],
              ),
        ]);
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.corrected});
  final Payment payment;
  final bool corrected;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(pakistanDate(payment.receivedAt));
    if (payment.isReversal) {
      return _Info('$date · Reversal', '${formatRupees(payment.amountPaisa.abs())} cancelled — ${payment.correctionReason}');
    }
    final replacement = payment.correctionOfPaymentId != null ? ' · Correction' : '';
    final note = payment.note == null ? '' : ' — ${payment.note}';
    return _Info('$date · ${payment.type.label}$replacement${corrected ? ' · Corrected' : ''}', '${formatRupees(payment.amountPaisa)}$note');
  }
}
