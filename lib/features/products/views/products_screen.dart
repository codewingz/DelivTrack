import 'package:flutter/material.dart';

import '../../../common_widgets/app_snack_bar.dart';
import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_segment_tabs.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../viewmodel/product_list_view_model.dart';
import 'product_form_sheet.dart';

/// Products list: a card edits the product and Archive/Restore moves it between the tabs.
///
/// [ProductsScreen.choose] is the same list used to pick a product for a parcel: only active
/// products, and a card pops the page with that [Product].
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repository})
    : choosing = false;
  const ProductsScreen.choose({super.key, required this.repository})
    : choosing = true;

  final ProductRepository repository;
  final bool choosing;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  late final _viewModel = ProductListViewModel(widget.repository);

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(message));

  Future<void> _openForm({Product? product}) async {
    final saved = await showProductFormSheet(
      context,
      widget.repository,
      product: product,
    );
    if (!mounted || !saved) return;
    _showMessage(product == null ? 'Product added.' : 'Product updated.');
  }

  Future<void> _toggleActive(Product product) async {
    if (product.isActive) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Archive "${product.name}"?',
        message: "Archived products can't be chosen for new parcels. Old parcels keep their details.",
        confirmLabel: 'Archive',
      );
      if (!mounted || !confirmed) return;
    }
    final error = await _viewModel.setActive(product, !product.isActive);
    if (!mounted) return;
    _showMessage(
      error ??
          (product.isActive
              ? '"${product.name}" archived.'
              : '"${product.name}" restored.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final ready = !_viewModel.isLoading && _viewModel.errorMessage == null;
        final active = _viewModel.activeCount;
        return SearchableListPage<Product>(
          title: widget.choosing ? 'Select product' : 'Products',
          subtitle: ready
              ? '$active active ${active == 1 ? 'product' : 'products'}'
              : null,
          viewModel: _viewModel,
          visible: _viewModel.visible,
          searchController: _search,
          searchHint: 'Search products',
          onQueryChanged: _viewModel.setQuery,
          addLabel: 'Add Product',
          onAdd: _openForm,
          header: widget.choosing
              ? null
              : AppSegmentTabs(
                  tabs: [
                    for (final (label, segment) in const [
                      ('Active', ProductSegment.active),
                      ('Archived', ProductSegment.archived),
                    ])
                      (
                        label: label,
                        count: _viewModel.countIn(segment),
                        selected: _viewModel.segment == segment,
                        onTap: () => _viewModel.setSegment(segment),
                      ),
                  ],
                ),
          emptyBuilder: _emptyState,
          itemBuilder: (context, product) => _ProductTile(
            product: product,
            onTap: widget.choosing
                ? () => Navigator.of(context).pop(product)
                : () => _openForm(product: product),
            onToggleActive: widget.choosing
                ? null
                : () => _toggleActive(product),
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    if (_viewModel.hasNoItems) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Add your first product.',
        actionLabel: 'Add Product',
        onAction: _openForm,
      );
    }
    if (_viewModel.query.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No products match "${_viewModel.query.trim()}"',
      );
    }
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: _viewModel.segment == ProductSegment.archived
          ? 'No archived products'
          : 'No active products',
    );
  }
}

/// One product: icon, name and selling unit, with Archive (or Restore) at the
/// end when [onToggleActive] is given.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onToggleActive,
  });
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    // Room for the button beside the name: not with large text or on a
    // narrow screen.
    final roomy =
        MediaQuery.widthOf(context) /
            MediaQuery.textScalerOf(context).scale(1) >=
        360;
    final toggle = onToggleActive == null
        ? null
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.label,
              backgroundColor: AppColors.closeButton,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            onPressed: onToggleActive,
            child: Text(
              product.isActive ? 'Archive' : 'Restore',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.name,
          key: const Key('product-name'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        StatusChip(label: product.saleUnit.label, color: AppColors.primary),
        if (!roomy && toggle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          toggle,
        ],
      ],
    );
    return App3DCard(
      glass: true,
      stripeColor: product.isActive ? AppColors.primary : AppColors.freeGift,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.brand100),
            ),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: details),
          if (roomy && toggle != null) ...[
            const SizedBox(width: AppSpacing.sm),
            toggle,
          ],
        ],
      ),
    );
  }
}
