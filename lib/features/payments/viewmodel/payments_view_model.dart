import '../../../core/time/pakistan_time.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../domain/payment_tabs.dart';

/// Payments: the selected list (newest parcel first, 20 at a time) and the header totals.
class PaymentsViewModel extends LiveListViewModel<Parcel> {
  PaymentsViewModel(ParcelRepository repository, {this.clock = const Clock()}) : super(() => repository.watchAll(includeArchived: true));

  static const pageSize = 20;

  final Clock clock;
  PaymentTab _tab = PaymentTab.pending;
  int _pages = 1;

  PaymentTab get tab => _tab;
  String get today => pakistanDate(clock.nowUtc());
  /// Lifetime figures: archived parcels keep their received money (an archived parcel owes nothing).
  PaymentTotals get totals => PaymentTotals.from(all);

  void select(PaymentTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    _pages = 1;
    notifyListeners();
  }

  /// Everything in the selected list.
  List<Parcel> get matching => [for (final parcel in all) if (!parcel.isArchived && _tab.includes(parcel, today)) parcel];

  /// The part of the list shown so far.
  List<Parcel> get visible => matching.take(_pages * pageSize).toList();

  bool get hasMore => matching.length > _pages * pageSize;

  void showMore() {
    _pages++;
    notifyListeners();
  }
}
