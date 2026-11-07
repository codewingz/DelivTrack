import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../viewmodel/customer_list_view_model.dart';

/// Customers list. Add/Edit open on their own full screens; the callbacks return the saved
/// customer's id (or null when the user left without saving).
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.repository, required this.onAdd, required this.onEdit});
  final CustomerRepository repository;
  final Future<String?> Function() onAdd;
  final Future<String?> Function(Customer customer) onEdit;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  late final _viewModel = CustomerListViewModel(widget.repository);

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final savedId = await widget.onAdd();
    if (!mounted || savedId == null) return;
    _showMessage('Customer added.');
  }

  Future<void> _edit(Customer customer) async {
    final savedId = await widget.onEdit(customer);
    if (!mounted || savedId == null) return;
    _showMessage('Customer updated.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => SearchableListPage<Customer>(
        title: 'Customers',
        viewModel: _viewModel,
        visible: _viewModel.visible,
        searchController: _search,
        searchHint: 'Search name or phone',
        onQueryChanged: _viewModel.setQuery,
        addLabel: 'Add Customer',
        onAdd: _add,
        emptyBuilder: _emptyState,
        itemBuilder: (context, customer) => ListTile(
          minTileHeight: 64,
          title: Text(customer.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${customer.phone}\n${customer.address}', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _edit(customer),
        ),
      ),
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
    return EmptyState(icon: Icons.search_off_rounded, title: 'No customers match "${_viewModel.query.trim()}"');
  }
}
