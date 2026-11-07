import 'package:flutter/material.dart';
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

  Future<void> _receivePayment(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await showPaymentSheet(context, widget.repository, parcel)) {
      messenger.showSnackBar(const SnackBar(content: Text('Payment recorded.')));
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
              if (parcel != null && parcel.status != ParcelStatus.returned)
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
    return _ParcelView(parcel: parcel, repository: widget.repository, onReceivePayment: () => _receivePayment(parcel));
  }
}

class _ParcelView extends StatelessWidget {
  const _ParcelView({required this.parcel, required this.repository, required this.onReceivePayment});
  final Parcel parcel;
  final ParcelRepository repository;
  final VoidCallback onReceivePayment;

  @override
  Widget build(BuildContext context) {
    final isFree = parcel.method == CollectionMethod.giftFree;
    final canReceive = !isFree && parcel.status != ParcelStatus.returned && parcel.outstandingPaisa > 0;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(title: 'Parcel', children: [
            ParcelStatusChips(status: parcel.status, payment: parcel.paymentStatus),
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
            _Info('Postal reference', parcel.postalReference.isEmpty ? 'Not entered yet' : parcel.postalReference),
            _Info('Delivery charges', parcel.deliveryChargePaisa == null ? 'Not entered yet' : formatRupees(parcel.deliveryChargePaisa!)),
            if (parcel.packedWeightGrams != null) _Info('Packed parcel weight', formatKg(parcel.packedWeightGrams!)),
          ]),
          _Section(title: 'Payment', children: [
            _Info('Expected amount', isFree ? 'None (Gift / Free)' : formatRupees(parcel.expectedPaisa)),
            _Info('Received', formatRupees(parcel.receivedPaisa)),
            _Info('Outstanding', formatRupees(parcel.outstandingPaisa)),
            if (parcel.estimatedPaymentDate != null) _Info('Estimated payment date', formatDate(parcel.estimatedPaymentDate!)),
            if (canReceive) PrimaryButton(label: 'Mark Payment Received', onPressed: onReceivePayment),
          ]),
          if (!isFree) _PaymentHistory(repository: repository, parcelId: parcel.id),
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
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({required this.repository, required this.parcelId});
  final ParcelRepository repository;
  final String parcelId;

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  late final Stream<List<Payment>> _payments = widget.repository.watchPayments(widget.parcelId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Payment>>(
      stream: _payments,
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const <Payment>[];
        return _Section(title: 'Payment history', children: [
          if (snapshot.hasError)
            const _Info('Payments', "Couldn't load the payments.")
          else if (payments.isEmpty)
            const _Info('Payments', 'No payments received yet')
          else
            for (final payment in payments)
              _Info(
                '${formatDate(pakistanDate(payment.receivedAt))} · ${payment.type.label}',
                '${formatRupees(payment.amountPaisa)}${payment.note == null ? '' : ' — ${payment.note}'}',
              ),
        ]);
      },
    );
  }
}
