import '../../../core/view_models/live_list_view_model.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';

/// The user's parcels, newest first. Search and filters come with the search feature.
class ParcelListViewModel extends LiveListViewModel<Parcel> {
  ParcelListViewModel(ParcelRepository repository) : super(repository.watchAll);
}
