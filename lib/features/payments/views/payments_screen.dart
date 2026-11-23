import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/liquid_glass.dart';
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
  const PaymentsScreen({
    super.key,
    required this.repository,
    required this.onOpen,
    this.clock = const Clock(),
  });
  final ParcelRepository repository;
  final void Function(Parcel parcel) onOpen;
  final Clock clock;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final _viewModel = PaymentsViewModel(
    widget.repository,
    clock: widget.clock,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _receive(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await showPaymentSheet(context, widget.repository, parcel)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment recorded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final ready = _viewModel.errorMessage == null && !_viewModel.isLoading;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        // The totals sit half over the header's bottom edge and stay put.
        // With large text or a small screen they scroll with the list.
        final pinTotals =
            ready &&
            textScale <= 1.3 &&
            MediaQuery.heightOf(context) >= 480 &&
            MediaQuery.widthOf(context) >= 340;
        final totalsHeight = 28 + 56 * textScale;
        final pending = _viewModel.pendingCount;
        return Scaffold(
          // The backdrop continues behind the header's curve and the totals.
          extendBodyBehindAppBar: true,
          appBar: appCurvedAppBar(
            toolbarHeight: AppBarTitle.heightFor(context),
            title: const AppBarTitle(
              'Payments',
              subtitle: 'Collections and balances',
              icon: Icons.payments_outlined,
            ),
            actions: [
              if (ready && MediaQuery.widthOf(context) / textScale >= 360)
                _PendingPill(count: pending),
            ],
            bottomOverhang: pinTotals ? totalsHeight / 2 + AppSpacing.sm : 0,
            bottom: pinTotals
                ? PreferredSize(
                    preferredSize: Size.fromHeight(
                      totalsHeight + AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxWidth),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child: SizedBox(
                            height: totalsHeight,
                            child: _Totals(totals: _viewModel.totals),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          body: LiquidBackground(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: _body(showTotals: !pinTotals),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const double _maxWidth = 640;

  Widget _body({required bool showTotals}) {
    if (_viewModel.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load payments",
        message: _viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: _viewModel.retry,
      );
    }
    if (_viewModel.isLoading) {
      return const SingleChildScrollView(child: ListSkeleton());
    }
    final rows = _viewModel.visible;
    return RefreshIndicator(
      onRefresh: () async => _viewModel.retry(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showTotals)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: _Totals(totals: _viewModel.totals),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: _TabBar(
                selected: _viewModel.tab,
                onSelected: _viewModel.select,
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.payments_outlined,
                title: 'Nothing in ${_viewModel.tab.label}',
                message: _emptyMessage(_viewModel.tab),
              ),
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
            SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  onPressed: _viewModel.showMore,
                  child: const Text('Show more'),
                ),
              ),
            ),
          const SliverPadding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
          ),
        ],
      ),
    );
  }

  static String _emptyMessage(PaymentTab tab) => switch (tab) {
    PaymentTab.pending =>
      'Parcels that have not received anything yet appear here.',
    PaymentTab.partial =>
      'Parcels with part of the money received appear here.',
    PaymentTab.received => 'Parcels paid in full appear here.',
    PaymentTab.postOffice => 'Post office collection parcels appear here.',
    PaymentTab.advance => 'Advance parcels appear here.',
    PaymentTab.payLater =>
      'Pay Later parcels that still owe money appear here.',
    PaymentTab.overdue => 'Pay Later payments past their date appear here.',
    PaymentTab.review =>
      'Returned parcels that received or owe money appear here for review.',
  };
}

/// "3 pending" in the header.
class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '$count pending',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.mint,
          ),
        ),
      ),
    );
  }
}

/// The three figures side by side in one glass strip.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final PaymentTotals totals;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat(
        label: 'Outstanding',
        value: formatRupees(totals.outstandingPaisa),
        color: AppColors.pending,
      ),
      _Stat(
        label: 'Pay Later balance',
        value: formatRupees(totals.payLaterPaisa),
        color: AppColors.textPrimary,
      ),
      _Stat(
        label: 'Advance received',
        value: formatRupees(totals.advancePaisa),
        color: AppColors.primary,
      ),
    ];
    return GlassSurface(
      radius: AppRadius.card,
      blurSigma: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (final (index, stat) in stats.indexed) ...[
                if (index > 0)
                  const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: stat),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // An amount is never wrapped or cut: a long one shrinks to fit.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
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
              child: ChoiceChip(
                label: Text(tab.label),
                selected: tab == selected,
                showCheckmark: false,
                backgroundColor: AppColors.glassFill,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tab == selected ? Colors.white : AppColors.textPrimary,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: tab == selected
                        ? AppColors.primary
                        : AppColors.glassEdge,
                  ),
                ),
                onSelected: (_) => onSelected(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.parcel,
    required this.tab,
    required this.onOpen,
    required this.onReceive,
  });
  final Parcel parcel;
  final PaymentTab tab;
  final VoidCallback onOpen;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final canReceive =
        parcel.status != ParcelStatus.returned && parcel.outstandingPaisa > 0;
    final date = parcel.estimatedPaymentDate;
    final isUnpaid = parcel.outstandingPaisa > 0;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: App3DCard(
        glass: true,
        stripeColor: isUnpaid ? AppColors.stripeDue : AppColors.primary,
        onTap: onOpen,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        parcel.orderNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      ParcelStatusChips(
                        status: parcel.status,
                        payment: parcel.paymentStatus,
                        reviewRequired: parcel.paymentReviewRequired,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // As wide as its text (so it sits at the edge), up to a little
                // under half the screen; beyond that it wraps.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.widthOf(context) * 0.45,
                  ),
                  child: Text(
                    'Balance ${formatRupees(parcel.outstandingPaisa)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isUnpaid ? AppColors.pending : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.customerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Expected ${formatRupees(parcel.expectedPaisa)} · Received ${formatRupees(parcel.receivedPaisa)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (parcel.method == CollectionMethod.payLater)
                        Text(
                          date == null
                              ? 'No date set'
                              : 'Pay Later date ${formatDate(date)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tab == PaymentTab.overdue
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canReceive) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _ReceiveButton(onPressed: onReceive),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The small glass "Receive" pill on a payment card.
class _ReceiveButton extends StatelessWidget {
  const _ReceiveButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.pill,
      ledgeHeight: 3,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Receive',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
