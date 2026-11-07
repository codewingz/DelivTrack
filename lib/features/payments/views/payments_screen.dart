import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../parcels/views/parcel_status_chips.dart';
import '../../parcels/views/payment_sheet.dart';
import '../domain/payment_tabs.dart';
import '../viewmodel/payments_view_model.dart';

/// Where the money stands: totals on top, then one list per payment state.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.repository, required this.onOpen, this.clock = const Clock()});
  final ParcelRepository repository;
  final void Function(Parcel parcel) onOpen;
  final Clock clock;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final _viewModel = PaymentsViewModel(widget.repository, clock: widget.clock);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _receive(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await showPaymentSheet(context, widget.repository, parcel)) {
      messenger.showSnackBar(const SnackBar(content: Text('Payment recorded.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(listenable: _viewModel, builder: (context, _) => _body()),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_viewModel.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load payments",
        message: _viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: _viewModel.retry,
      );
    }
    if (_viewModel.isLoading) return const SingleChildScrollView(child: ListSkeleton());
    final rows = _viewModel.visible;
    return RefreshIndicator(
      onRefresh: () async => _viewModel.retry(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Totals(totals: _viewModel.totals)),
          SliverToBoxAdapter(child: _TabBar(selected: _viewModel.tab, onSelected: _viewModel.select)),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.payments_outlined, title: 'Nothing in ${_viewModel.tab.label}', message: _emptyMessage(_viewModel.tab)),
            )
          else
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => _PaymentTile(
                parcel: rows[index],
                tab: _viewModel.tab,
                onOpen: () => widget.onOpen(rows[index]),
                onReceive: () => _receive(rows[index]),
              ),
            ),
          if (_viewModel.hasMore)
            SliverToBoxAdapter(child: Center(child: TextButton(onPressed: _viewModel.showMore, child: const Text('Show more')))),
          const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl)),
        ],
      ),
    );
  }

  static String _emptyMessage(PaymentTab tab) => switch (tab) {
        PaymentTab.pending => 'Parcels that have not received anything yet appear here.',
        PaymentTab.partial => 'Parcels with part of the money received appear here.',
        PaymentTab.received => 'Parcels paid in full appear here.',
        PaymentTab.advance => 'Advance parcels appear here.',
        PaymentTab.payLater => 'Pay Later parcels that still owe money appear here.',
        PaymentTab.overdue => 'Pay Later payments past their date appear here.',
        PaymentTab.review => 'Returned parcels that received or owe money appear here for review.',
      };
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final PaymentTotals totals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _Stat(label: 'Outstanding', value: formatRupees(totals.outstandingPaisa)),
          _Stat(label: 'Pay Later balance', value: formatRupees(totals.payLaterPaisa)),
          _Stat(label: 'Advance received', value: formatRupees(totals.advancePaisa)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelected});
  final PaymentTab selected;
  final ValueChanged<PaymentTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final tab in PaymentTab.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(label: Text(tab.label), selected: tab == selected, onSelected: (_) => onSelected(tab)),
            ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.parcel, required this.tab, required this.onOpen, required this.onReceive});
  final Parcel parcel;
  final PaymentTab tab;
  final VoidCallback onOpen;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final canReceive = parcel.status != ParcelStatus.returned && parcel.outstandingPaisa > 0;
    final date = parcel.estimatedPaymentDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const SizedBox(height: AppSpacing.xs),
                ParcelStatusChips(status: parcel.status, payment: parcel.paymentStatus, reviewRequired: parcel.paymentReviewRequired),
                const SizedBox(height: AppSpacing.sm),
                Text(parcel.customerName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  'Expected ${formatRupees(parcel.expectedPaisa)} · Received ${formatRupees(parcel.receivedPaisa)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text('Balance ${formatRupees(parcel.outstandingPaisa)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (parcel.method == CollectionMethod.payLater)
                  Text(
                    date == null ? 'No date set' : 'Pay Later date ${formatDate(date)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tab == PaymentTab.overdue ? AppColors.error : AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        if (canReceive)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
            child: TextButton(onPressed: onReceive, child: const Text('Receive')),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
