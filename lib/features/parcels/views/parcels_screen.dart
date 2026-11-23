import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_segment_tabs.dart';
import '../../../common_widgets/count_badge.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../dashboard/domain/dashboard_stats.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_search.dart';
import '../viewmodel/parcel_list_view_model.dart';
import 'parcel_filter_sheet.dart';

/// All parcels, newest first, with search and filters. Add opens the full-screen form; the callbacks
/// return the new parcel's id (or null when the user left without saving).
class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({
    super.key,
    required this.repository,
    required this.onAdd,
    required this.onOpen,
    this.initialFilters,
    this.clock = const Clock(),
  });
  final ParcelRepository repository;
  final Future<void> Function() onAdd;
  final void Function(Parcel parcel) onOpen;

  /// Filters to start with, or to switch to when Home opens the list from one of its figures.
  final ParcelFilters? initialFilters;
  final Clock clock;

  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> {
  late final _viewModel = ParcelListViewModel(
    widget.repository,
    clock: widget.clock,
  );
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      _viewModel.setFilters(widget.initialFilters!);
    }
  }

  @override
  void didUpdateWidget(ParcelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filters = widget.initialFilters;
    if (filters != null && !identical(filters, oldWidget.initialFilters)) {
      _debounce?.cancel();
      _search.clear();
      _viewModel.setQuery('');
      _viewModel.setFilters(filters);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Runs the search 300 ms after the last keystroke, not on every one.
  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _viewModel.setQuery(text),
    );
  }

  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _viewModel.clearAll();
  }

  Future<void> _openFilters() async {
    final filters = await showParcelFilterSheet(
      context,
      current: _viewModel.filters,
      products: _viewModel.products,
      today: _viewModel.today,
      // The payment-date filter needs dates fetched after Apply, so there is
      // no count to show for it beforehand.
      countFor: (filters) =>
          filters.hasReceivedDates ||
              _viewModel.isLoadingPaymentDates ||
              _viewModel.paymentDatesError != null
          ? null
          : _viewModel.matchingWith(filters).length,
    );
    if (filters != null) _viewModel.setFilters(filters);
  }

  /// "4 parcels" / "2 matches", or nothing while the list is not ready.
  String? _countLine() {
    if (_viewModel.isLoading ||
        _viewModel.errorMessage != null ||
        _viewModel.isLoadingPaymentDates) {
      return null;
    }
    final count = _viewModel.matching.length;
    return _viewModel.isNarrowed
        ? '$count ${count == 1 ? 'match' : 'matches'}'
        : '$count ${count == 1 ? 'parcel' : 'parcels'}';
  }

  /// Money still to collect on the active parcels (the same figure as Home).
  int _outstandingPaisa() => DashboardStats.from(
    _viewModel.all,
    _viewModel.today,
  ).totalOutstandingPaisa;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final visible = _viewModel.visible;
        return SearchableListPage<Parcel>(
          title: 'Parcels',
          titleIcon: Icons.inventory_2_outlined,
          subtitle: _countLine(),
          // Left out when there is no room beside the title (small screen
          // or large text); Home shows the same figure.
          actions: [
            if (MediaQuery.widthOf(context) /
                    MediaQuery.textScalerOf(context).scale(1) >=
                360)
              AppBarStatPill(
                label: 'Total outstanding',
                value: formatRupees(_outstandingPaisa()),
              ),
          ],
          searchTrailing: _FiltersButton(
            activeCount: _viewModel.filters.activeCount,
            onPressed: _openFilters,
          ),
          viewModel: _viewModel,
          visible: visible,
          searchController: _search,
          searchHint: 'Order, VPP number, customer, product',
          onQueryChanged: _onQueryChanged,
          header: _FilterBar(viewModel: _viewModel),
          footer: _viewModel.hasMore
              ? TextButton(
                  onPressed: _viewModel.loadMore,
                  child: const Text('Load more'),
                )
              : null,
          addLabel: 'Add Parcel',
          onAdd: widget.onAdd,
          emptyBuilder: () => _viewModel.isLoadingPaymentDates
              ? const EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'Checking payment dates...',
                )
              : _viewModel.paymentDatesError != null
              ? EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: "Couldn't check payment dates",
                  message: _viewModel.paymentDatesError,
                  actionLabel: 'Retry',
                  onAction: _viewModel.retryPaymentDates,
                )
              : _viewModel.isNarrowed
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No parcels match',
                  message: 'Try a different search or clear the filters.',
                  actionLabel: 'Clear search and filters',
                  onAction: _clearAll,
                )
              : EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No parcels yet',
                  message: 'Add your first parcel.',
                  actionLabel: 'Add Parcel',
                  onAction: widget.onAdd,
                ),
          itemBuilder: (context, parcel) =>
              ParcelTile(parcel: parcel, onTap: () => widget.onOpen(parcel)),
        );
      },
    );
  }
}

/// The All / Pending / Settled tabs and the active filters as removable chips.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel});
  final ParcelListViewModel viewModel;

  static String _range(String? from, String? to) => switch ((from, to)) {
    (final f?, final t?) => '${formatDate(f)} – ${formatDate(t)}',
    (final f?, null) => 'from ${formatDate(f)}',
    (null, final t?) => 'until ${formatDate(t)}',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final filters = viewModel.filters;
    final chips = <({String label, ParcelFilters without})>[
      if (filters.hasSendingDates)
        (
          label: 'Sent ${_range(filters.sendingFrom, filters.sendingTo)}',
          without: filters.copyWith(sendingFrom: null, sendingTo: null),
        ),
      if (filters.hasReceivedDates)
        (
          label: 'Paid ${_range(filters.receivedFrom, filters.receivedTo)}',
          without: filters.copyWith(receivedFrom: null, receivedTo: null),
        ),
      if (filters.productId != null)
        (
          label: 'Product: ${filters.productName}',
          without: filters.copyWith(productId: null, productName: null),
        ),
      if (filters.methods.isNotEmpty)
        (
          label: 'Type: ${filters.methods.map((m) => m.label).join(', ')}',
          without: filters.copyWith(methods: {}),
        ),
      // A choice made with the tabs is already shown by the tabs.
      if (filters.payments.isNotEmpty && !_PaymentTabs.isTabChoice(filters))
        (
          label: 'Payment: ${filters.payments.map((p) => p.label).join(', ')}',
          without: filters.copyWith(payments: {}),
        ),
      if (filters.statuses.isNotEmpty)
        (
          label: 'Status: ${filters.statuses.map((s) => s.label).join(', ')}',
          without: filters.copyWith(statuses: {}),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaymentTabs(viewModel: viewModel),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final chip in chips)
                InputChip(
                  label: Text(
                    chip.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: AppColors.brand50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    side: const BorderSide(color: Color(0xFFCDE5D8)),
                  ),
                  onDeleted: () => viewModel.setFilters(chip.without),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Filters button beside the search box, with the number of active filter groups.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.activeCount, required this.onPressed});
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.control,
      blurSigma: 12,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          foregroundColor: AppColors.primary,
          // The glass panel draws the fill and the edge.
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
        onPressed: onPressed,
        icon: CountBadge(
          count: activeCount,
          child: const Icon(Icons.tune_rounded),
        ),
        label: const Text(
          'Filters',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// All / Pending / Settled: a shortcut for the payment filter. "Pending" is
/// anything still owed (pending or partly paid), "Settled" is fully paid.
class _PaymentTabs extends StatelessWidget {
  const _PaymentTabs({required this.viewModel});
  final ParcelListViewModel viewModel;

  static const _pending = {PaymentFilter.pending, PaymentFilter.partial};
  static const _settled = {PaymentFilter.received};

  static bool isTabChoice(ParcelFilters filters) =>
      _same(filters.payments, _pending) || _same(filters.payments, _settled);

  static bool _same(Set<PaymentFilter> a, Set<PaymentFilter> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    final filters = viewModel.filters;
    final tabs = <(String, Set<PaymentFilter>)>[
      ('All', const {}),
      ('Pending', _pending),
      ('Settled', _settled),
    ];
    return AppSegmentTabs(
      tabs: [
        for (final (label, payments) in tabs)
          (
            label: label,
            count: viewModel
                .matchingWith(filters.copyWith(payments: payments))
                .length,
            selected: _same(filters.payments, payments),
            onTap: () =>
                viewModel.setFilters(filters.copyWith(payments: payments)),
          ),
      ],
    );
  }
}

class ParcelTile extends StatelessWidget {
  const ParcelTile({
    super.key,
    required this.parcel,
    required this.onTap,
    this.onRestore,
  });
  final Parcel parcel;
  final VoidCallback onTap;

  /// Adds a footer with the parcel type and a Restore button (the archived
  /// list).
  final VoidCallback? onRestore;

  static Color _statusColor(ParcelStatus s) => switch (s) {
    ParcelStatus.draft => AppColors.freeGift,
    ParcelStatus.sent => AppColors.primary,
    ParcelStatus.returned => AppColors.credit,
  };

  @override
  Widget build(BuildContext context) {
    final isGift = parcel.method == CollectionMethod.giftFree;
    final owes = parcel.outstandingPaisa > 0;
    final reference = parcel.status == ParcelStatus.draft
        ? 'Awaiting handover'
        : parcel.postalReference.isEmpty
        ? 'No tracking number yet'
        : parcel.postalReference;
    final products = parcel.items.isEmpty
        ? null
        : parcel.items.length == 1
        ? parcel.items.first.productName
        : '${parcel.items.first.productName} +${parcel.items.length - 1}';

    return App3DCard(
      glass: true,
      stripeColor: parcel.isArchived
          ? AppColors.freeGift
          : parcel.status == ParcelStatus.draft || owes
          ? AppColors.stripeDue
          : AppColors.primary,
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
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
                        if (parcel.isArchived)
                          const StatusChip(
                            label: 'Archived',
                            color: AppColors.freeGift,
                          )
                        else
                          StatusChip(
                            label: parcel.status.label,
                            color: _statusColor(parcel.status),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          parcel.customerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (products != null)
                          Text(
                            '· $products',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.label,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '$reference · ${parcel.sendingDateLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isGift
                          ? 'Gift / Free'
                          : formatRupees(parcel.expectedPaisa),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: !isGift && !owes
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (owes)
                      StatusChip(
                        label: 'Due ${formatRupees(parcel.outstandingPaisa)}',
                        color: AppColors.pending,
                      )
                    else if (parcel.paymentStatus == PaymentStatus.received)
                      const StatusChip(label: 'Paid', color: AppColors.success)
                    else
                      StatusChip(
                        label: parcel.paymentStatus.label,
                        color: AppColors.freeGift,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (onRestore != null) ...[
            const Divider(height: AppSpacing.xxl, color: AppColors.border),
            // The button moves under the parcel type when both do not fit.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Text(
                  parcel.method.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.brand50,
                    side: const BorderSide(color: AppColors.brand100),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  onPressed: onRestore,
                  child: const Text(
                    'Restore',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
