import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../viewmodel/product_list_view_model.dart';

/// Pick one of the active products for a parcel line. Pops with the chosen [Product].
class ProductPickerScreen extends StatefulWidget {
  const ProductPickerScreen({super.key, required this.repository});
  final ProductRepository repository;

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  final _search = TextEditingController();
  late final _viewModel = ProductListViewModel(widget.repository);

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => SearchableListPage<Product>(
        title: 'Select product',
        viewModel: _viewModel,
        visible: _viewModel.visible,
        searchController: _search,
        searchHint: 'Search products',
        onQueryChanged: _viewModel.setQuery,
        emptyBuilder: () => _viewModel.query.trim().isNotEmpty
            ? EmptyState(icon: Icons.search_off_rounded, title: 'No products match "${_viewModel.query.trim()}"')
            : const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products to choose from',
                message: 'Add products under More → Products first.',
              ),
        itemBuilder: (context, product) => ListTile(
          minTileHeight: 56,
          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(product.saleUnit.label),
          onTap: () => Navigator.of(context).pop(product),
        ),
      ),
    );
  }
}
