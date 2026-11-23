import 'package:flutter/material.dart';

import '../../../common_widgets/app_snack_bar.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_search.dart';
import 'parcels_screen.dart';

/// Parcels that were archived, newest first, with search. A row opens the
/// parcel; Restore brings it back to the lists.
class ArchivedParcelsScreen extends StatefulWidget {
  const ArchivedParcelsScreen({
    super.key,
    required this.repository,
    required this.onOpen,
  });
  final ParcelRepository repository;
  final void Function(Parcel parcel) onOpen;

  @override
  State<ArchivedParcelsScreen> createState() => _ArchivedParcelsScreenState();
}

class _ArchivedParcelsViewModel extends LiveListViewModel<Parcel> {
  _ArchivedParcelsViewModel(ParcelRepository repository)
    : super(repository.watchArchived);

  String _query = '';
  String get query => _query;

  /// Archived parcels matching the search (order, tracking number, customer,
  /// product), as on the Parcels list.
  List<Parcel> get visible => [
    for (final parcel in all)
      if (parcelMatchesQuery(parcel, _query)) parcel,
  ];

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }
}

class _ArchivedParcelsScreenState extends State<ArchivedParcelsScreen> {
  late final _viewModel = _ArchivedParcelsViewModel(widget.repository);
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _restore(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.restore(parcel.id);
      messenger.showSnackBar(appSnackBar('${parcel.orderNumber} restored.'));
    } on AppFailure catch (e) {
      messenger.showSnackBar(appSnackBar(e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final ready = !_viewModel.isLoading && _viewModel.errorMessage == null;
        final count = _viewModel.all.length;
        return SearchableListPage<Parcel>(
          title: 'Archived parcels',
          subtitle: ready
              ? '$count archived ${count == 1 ? 'parcel' : 'parcels'}'
              : null,
          viewModel: _viewModel,
          visible: _viewModel.visible,
          searchController: _search,
          searchHint: 'Search archived order, customer',
          onQueryChanged: _viewModel.setQuery,
          emptyBuilder: () => _viewModel.query.trim().isNotEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title:
                      'No archived parcels match "${_viewModel.query.trim()}"',
                )
              : const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No archived parcels',
                  message: 'A draft parcel that has received no money can be archived from its details.',
                ),
          itemBuilder: (context, parcel) => ParcelTile(
            parcel: parcel,
            onTap: () => widget.onOpen(parcel),
            onRestore: () => _restore(parcel),
          ),
        );
      },
    );
  }
}
