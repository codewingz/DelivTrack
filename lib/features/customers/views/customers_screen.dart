import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_snack_bar.dart';
import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/initial_avatar.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../viewmodel/customer_list_view_model.dart';

/// Customers list. Add opens its own full screen (the callback returns the saved customer's id, or
/// null when the user left without saving); a row opens that customer's details.
///
/// [CustomersScreen.choose] is the same list used to pick a customer for a parcel: a row (or a newly
/// added customer) pops the page with that [Customer].
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.repository,
    required this.parcelRepository,
    required this.onAdd,
    required void Function(Customer customer) this.onOpen,
  });

  const CustomersScreen.choose({
    super.key,
    required this.repository,
    required this.parcelRepository,
    required this.onAdd,
  }) : onOpen = null;

  final CustomerRepository repository;
  final ParcelRepository parcelRepository;
  final Future<String?> Function() onAdd;

  /// Null when the page is used to choose a customer.
  final void Function(Customer customer)? onOpen;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  late final _viewModel = CustomerListViewModel(
    widget.repository,
    widget.parcelRepository,
  );

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(message));

  Future<void> _add() async {
    final savedId = await widget.onAdd();
    if (!mounted || savedId == null) return;
    if (widget.onOpen != null) return _showMessage('Customer added.');
    // Choosing: the new customer is the choice, once the live list has it.
    final customers = await widget.repository
        .watchAll()
        .firstWhere((list) => list.any((c) => c.id == savedId))
        .timeout(const Duration(seconds: 10), onTimeout: () => const []);
    if (!mounted) return;
    final created = customers.where((c) => c.id == savedId);
    if (created.isNotEmpty) Navigator.of(context).pop(created.first);
  }

  void _open(Customer customer) {
    final onOpen = widget.onOpen;
    onOpen == null ? Navigator.of(context).pop(customer) : onOpen(customer);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final ready = !_viewModel.isLoading && _viewModel.errorMessage == null;
        final count = _viewModel.visible.length;
        // Room for things side by side: not with large text or on a narrow
        // screen.
        final roomy =
            MediaQuery.widthOf(context) /
                MediaQuery.textScalerOf(context).scale(1) >=
            360;
        return SearchableListPage<Customer>(
          title: widget.onOpen == null ? 'Select customer' : 'Customers',
          titleIcon: Icons.people_outline_rounded,
          subtitle: ready
              ? '$count ${count == 1 ? 'customer' : 'customers'}'
              : null,
          actions: [
            // Not while choosing: the title needs the room.
            if (ready && roomy && widget.onOpen != null)
              AppBarStatPill(
                label: 'Total due',
                value: formatRupees(_viewModel.totalOutstandingPaisa),
              ),
          ],
          viewModel: _viewModel,
          visible: _viewModel.visible,
          searchController: _search,
          searchHint: 'Search name or phone',
          onQueryChanged: _viewModel.setQuery,
          addLabel: 'Add Customer',
          onAdd: _add,
          emptyBuilder: _emptyState,
          itemBuilder: (context, customer) => _CustomerTile(
            customer: customer,
            figures: _viewModel.figuresOf(customer.id),
            roomy: roomy,
            onTap: () => _open(customer),
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    if (_viewModel.hasNoItems) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No customers yet',
        message: 'Add your first customer.',
        actionLabel: 'Add Customer',
        onAction: _add,
      );
    }
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No customers match "${_viewModel.query.trim()}"',
    );
  }
}

/// One customer: initial, name, phone and address, with the parcel count and
/// what is still owed at the end.
class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.figures,
    required this.roomy,
    required this.onTap,
  });
  final Customer customer;
  final CustomerFigures figures;
  final bool roomy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDebt = figures.outstandingPaisa > 0;
    final figuresColumn = Column(
      crossAxisAlignment: roomy
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${figures.parcels} ${figures.parcels == 1 ? 'parcel' : 'parcels'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        if (hasDebt) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Outstanding ${formatRupees(figures.outstandingPaisa)}',
            excludeSemantics: true,
            child: StatusChip(
              label: formatRupees(figures.outstandingPaisa),
              color: AppColors.pending,
            ),
          ),
        ],
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          customer.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          customer.phone,
          style: const TextStyle(fontSize: 14, color: AppColors.label),
        ),
        Text(
          customer.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (!roomy) ...[const SizedBox(height: AppSpacing.sm), figuresColumn],
      ],
    );
    return App3DCard(
      glass: true,
      stripeColor: hasDebt ? AppColors.stripeDue : AppColors.primary,
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          InitialAvatar(name: customer.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: details),
          if (roomy) ...[const SizedBox(width: AppSpacing.sm), figuresColumn],
          const Icon(Icons.chevron_right_rounded, color: AppColors.label),
        ],
      ),
    );
  }
}
