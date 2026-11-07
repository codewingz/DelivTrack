import 'dart:async';
import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../viewmodel/customer_list_view_model.dart';

/// Pick a customer for a parcel. Pops with the chosen [Customer].
/// "Add Customer" opens the full-screen form through [onAdd]; the new customer is then chosen automatically.
class CustomerPickerScreen extends StatefulWidget {
  const CustomerPickerScreen({super.key, required this.repository, required this.onAdd});
  final CustomerRepository repository;
  final Future<String?> Function() onAdd;

  @override
  State<CustomerPickerScreen> createState() => _CustomerPickerScreenState();
}

class _CustomerPickerScreenState extends State<CustomerPickerScreen> {
  final _search = TextEditingController();
  late final _viewModel = CustomerListViewModel(widget.repository);

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _addAndSelect() async {
    final newId = await widget.onAdd();
    if (!mounted || newId == null) return;
    final customers = await widget.repository
        .watchAll()
        .firstWhere((list) => list.any((c) => c.id == newId))
        .timeout(const Duration(seconds: 10), onTimeout: () => const []);
    if (!mounted) return;
    final created = customers.where((c) => c.id == newId);
    if (created.isNotEmpty) Navigator.of(context).pop(created.first);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => SearchableListPage<Customer>(
        title: 'Select customer',
        viewModel: _viewModel,
        visible: _viewModel.visible,
        searchController: _search,
        searchHint: 'Search name or phone',
        onQueryChanged: _viewModel.setQuery,
        addLabel: 'New Customer',
        onAdd: _addAndSelect,
        emptyBuilder: () => _viewModel.hasNoItems
            ? EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No customers yet',
                message: 'Add the customer for this parcel.',
                actionLabel: 'New Customer',
                onAction: _addAndSelect,
              )
            : EmptyState(icon: Icons.search_off_rounded, title: 'No customers match "${_viewModel.query.trim()}"'),
        itemBuilder: (context, customer) => ListTile(
          minTileHeight: 64,
          title: Text(customer.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${customer.phone}\n${customer.address}', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          onTap: () => Navigator.of(context).pop(customer),
        ),
      ),
    );
  }
}
