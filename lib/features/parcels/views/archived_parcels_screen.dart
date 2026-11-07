import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/searchable_list_page.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import 'parcels_screen.dart';

/// Parcels that were archived, newest first. A row opens the parcel, where it can be restored.
class ArchivedParcelsScreen extends StatefulWidget {
  const ArchivedParcelsScreen({super.key, required this.repository, required this.onOpen});
  final ParcelRepository repository;
  final void Function(Parcel parcel) onOpen;

  @override
  State<ArchivedParcelsScreen> createState() => _ArchivedParcelsScreenState();
}

class _ArchivedParcelsViewModel extends LiveListViewModel<Parcel> {
  _ArchivedParcelsViewModel(ParcelRepository repository) : super(repository.watchArchived);
}

class _ArchivedParcelsScreenState extends State<ArchivedParcelsScreen> {
  late final _viewModel = _ArchivedParcelsViewModel(widget.repository);

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
        title: 'Archived parcels',
        viewModel: _viewModel,
        visible: _viewModel.all,
        emptyBuilder: () => const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No archived parcels',
          message: 'A parcel with nothing left to chase can be archived from its details.',
        ),
        itemBuilder: (context, parcel) => ParcelTile(parcel: parcel, onTap: () => widget.onOpen(parcel)),
      ),
    );
  }
}
