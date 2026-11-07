import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../viewmodel/parcel_list_view_model.dart';
import 'parcel_status_chips.dart';

/// All parcels, newest first. Add opens the full-screen form; the callbacks return the new
/// parcel's id (or null when the user left without saving).
class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({super.key, required this.repository, required this.onAdd, required this.onOpen});
  final ParcelRepository repository;
  final Future<void> Function() onAdd;
  final void Function(Parcel parcel) onOpen;

  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> {
  late final _viewModel = ParcelListViewModel(widget.repository);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => SearchableListPage<Parcel>(
        title: 'Parcels',
        viewModel: _viewModel,
        visible: _viewModel.all,
        addLabel: 'Add Parcel',
        onAdd: widget.onAdd,
        emptyBuilder: () => EmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'No parcels yet',
          message: 'Add your first parcel.',
          actionLabel: 'Add Parcel',
          onAction: widget.onAdd,
        ),
        itemBuilder: (context, parcel) => ParcelTile(parcel: parcel, onTap: () => widget.onOpen(parcel)),
      ),
    );
  }
}

class ParcelTile extends StatelessWidget {
  const ParcelTile({super.key, required this.parcel, required this.onTap});
  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = parcel.postalReference.isEmpty ? 'No postal reference yet' : '${parcel.serviceLabel} · ${parcel.postalReference}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parcel.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: AppSpacing.xs),
            ParcelStatusChips(status: parcel.status, payment: parcel.paymentStatus),
            const SizedBox(height: AppSpacing.sm),
            Text(parcel.customerName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(reference, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(
              '${parcel.sendingDateLabel} · ${parcel.method == CollectionMethod.giftFree ? 'Gift / Free' : formatRupees(parcel.expectedPaisa)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
