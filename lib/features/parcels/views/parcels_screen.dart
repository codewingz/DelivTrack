import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/count_badge.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_search.dart';
import '../viewmodel/parcel_list_view_model.dart';
import 'parcel_filter_sheet.dart';
import 'parcel_status_chips.dart';

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
    );
    if (filters != null) _viewModel.setFilters(filters);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final visible = _viewModel.visible;
        return SearchableListPage<Parcel>(
          title: 'Parcels',
          viewModel: _viewModel,
          visible: visible,
          searchController: _search,
          searchHint: 'Order, VPP number, customer, product',
          onQueryChanged: _onQueryChanged,
          header: _FilterBar(
            viewModel: _viewModel,
            onOpenFilters: _openFilters,
          ),
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

/// The Filters button (with the number of active groups), the active filters as removable chips and
/// how many parcels match.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel, required this.onOpenFilters});
  final ParcelListViewModel viewModel;
  final VoidCallback onOpenFilters;

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
      if (filters.payments.isNotEmpty)
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
    final count = viewModel.matching.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: AppColors.border, width: 1.2),
                backgroundColor: AppColors.surface,
              ),
              onPressed: onOpenFilters,
              icon: CountBadge(
                count: filters.activeCount,
                child: const Icon(Icons.filter_list_rounded),
              ),
              label: const Text('Filters'),
            ),
            const SizedBox(width: AppSpacing.md),
            if (!viewModel.isLoading &&
                viewModel.errorMessage == null &&
                !viewModel.isLoadingPaymentDates)
              Flexible(
                child: Text(
                  viewModel.isNarrowed
                      ? '$count ${count == 1 ? 'match' : 'matches'}'
                      : '$count ${count == 1 ? 'parcel' : 'parcels'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
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
                    borderRadius: BorderRadius.circular(999),
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

class ParcelTile extends StatelessWidget {
  const ParcelTile({super.key, required this.parcel, required this.onTap});
  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = parcel.postalReference.isEmpty
        ? 'No tracking number yet'
        : parcel.postalReference;
    final isUnpaidOrDraft = parcel.status == ParcelStatus.draft ||
        parcel.outstandingPaisa > 0;
    final stripeColor = isUnpaidOrDraft
        ? const Color(0xFFD97706)
        : const Color(0xFF115E46);

    return App3DCard(
      stripeColor: stripeColor,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  color: Color(0xFF115E46),
                ),
              ),
              Text(
                parcel.method == CollectionMethod.giftFree
                    ? 'Gift / Free'
                    : formatRupees(parcel.expectedPaisa),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ParcelStatusChips(
                status: parcel.status,
                payment: parcel.paymentStatus,
              ),
              if (parcel.method != CollectionMethod.giftFree)
                Text(
                  'Balance ${formatRupees(parcel.outstandingPaisa)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            parcel.customerName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          Text(
            reference,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${parcel.sendingDateLabel} · ${parcel.method == CollectionMethod.giftFree ? 'Gift / Free' : formatRupees(parcel.expectedPaisa)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
