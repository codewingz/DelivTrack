import 'package:flutter/material.dart';
import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../constants/app_colors.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../viewmodel/product_list_view_model.dart';
import 'product_form_sheet.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repository});
  final ProductRepository repository;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openForm({Product? product}) async {
    final saved = await showProductFormSheet(context, widget.repository, product: product);
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
    _showMessage(error ?? (product.isActive ? '"${product.name}" archived.' : '"${product.name}" restored.'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => SearchableListPage<Product>(
        title: 'Products',
        viewModel: _viewModel,
        visible: _viewModel.visible,
        searchController: _search,
        searchHint: 'Search products',
        onQueryChanged: _viewModel.setQuery,
        addLabel: 'Add Product',
        onAdd: _openForm,
        header: AppChoiceField<ProductSegment>(
          initialValue: _viewModel.segment,
          options: const [
            (value: ProductSegment.active, label: 'Active'),
            (value: ProductSegment.archived, label: 'Archived'),
          ],
          onChanged: _viewModel.setSegment,
        ),
        emptyBuilder: _emptyState,
        itemBuilder: (context, product) => _ProductTile(
          product: product,
          onEdit: () => _openForm(product: product),
          onToggleActive: () => _toggleActive(product),
        ),
      ),
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
      return EmptyState(icon: Icons.search_off_rounded, title: 'No products match "${_viewModel.query.trim()}"');
    }
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: _viewModel.segment == ProductSegment.archived ? 'No archived products' : 'No active products',
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onEdit, required this.onToggleActive});
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      title: Text(product.name, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text(product.saleUnit.label),
      onTap: onEdit,
      trailing: PopupMenuButton<VoidCallback>(
        tooltip: 'Options for ${product.name}',
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(value: onEdit, child: const Text('Edit')),
          PopupMenuItem(value: onToggleActive, child: Text(product.isActive ? 'Archive' : 'Restore')),
        ],
        icon: const Icon(Icons.more_vert, color: AppColors.label),
      ),
    );
  }
}
