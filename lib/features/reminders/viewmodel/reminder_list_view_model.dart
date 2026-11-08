import '../../../core/time/pakistan_time.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../domain/reminder_rules.dart';

/// The user's Pay Later follow-ups, derived live from their parcels (there is no separate reminder
/// record to keep in step with the parcel).
class ReminderListViewModel extends LiveListViewModel<Parcel> {
  /// [includeArchived] is for the dashboard, whose money totals keep archived parcels; the reminders
  /// themselves only ever look at active parcels.
  ReminderListViewModel(
    ParcelRepository repository, {
    this.clock = const Clock(),
    bool includeArchived = false,
  }) : super(() => repository.watchAll(includeArchived: includeArchived));

  final Clock clock;

  String get today => pakistanDate(clock.nowUtc());
  Reminders get reminders => Reminders.from([
    for (final parcel in all)
      if (!parcel.isArchived) parcel,
  ], today);
}
