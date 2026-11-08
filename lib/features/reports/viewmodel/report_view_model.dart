import '../../../core/errors/app_failure.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../parcels/domain/payment.dart';
import '../domain/reports.dart';

/// One report over the user's live parcels, limited to an optional From / To date range. The payment
/// history also covers archived parcels (archiving never removes received money from the history).
class ReportViewModel extends LiveListViewModel<Parcel> {
  ReportViewModel(this._repository, this.type, {this.clock = const Clock()})
    : super(() => _repository.watchAll(includeArchived: type.needsPayments)) {
    addListener(_loadPaymentsOnceParcelsArrive);
  }

  final ParcelRepository _repository;
  final ReportType type;
  final Clock clock;

  String? _from;
  String? _to;
  Map<String, List<Payment>>? _payments;
  String? _paymentsError;
  int _lookup = 0;
  bool _requested = false;
  bool _disposed = false;

  String? get from => _from;
  String? get to => _to;
  String get today => pakistanDate(clock.nowUtc());

  /// The range ends before it starts.
  String? get rangeProblem =>
      _from != null && _to != null && _to!.compareTo(_from!) < 0
      ? 'The To date is before the From date.'
      : null;

  /// True while the payments the history needs are still being fetched.
  bool get isLoadingPayments =>
      type.needsPayments && _payments == null && _paymentsError == null;
  String? get paymentsError => _paymentsError;

  ReportResult? get result {
    if (isLoading ||
        isLoadingPayments ||
        _paymentsError != null ||
        rangeProblem != null) {
      return null;
    }
    return buildReport(
      type,
      all,
      payments: _payments ?? const {},
      from: _from,
      to: _to,
      today: today,
    );
  }

  void setRange({String? from, String? to}) {
    _from = from;
    _to = to;
    notifyListeners();
  }

  void retryPayments() => _loadPayments();

  /// Only parcels that can hold a payment are asked about, so the parcels have to be here first.
  void _loadPaymentsOnceParcelsArrive() {
    if (!type.needsPayments || _requested || isLoading) return;
    _requested = true;
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final mine = ++_lookup;
    _payments = null;
    _paymentsError = null;
    notifyListeners();
    try {
      final ids = [
        for (final parcel in all)
          if (parcel.method != CollectionMethod.giftFree) parcel.id,
      ];
      final payments = await _repository.paymentsFor(ids);
      if (_disposed || mine != _lookup) return;
      _payments = payments;
    } on AppFailure catch (e) {
      if (_disposed || mine != _lookup) return;
      _paymentsError = e.message;
    }
    notifyListeners();
  }

  @override
  void retry() {
    _requested = false;
    _payments = null;
    super.retry();
  }

  @override
  void dispose() {
    removeListener(_loadPaymentsOnceParcelsArrive);
    _disposed = true;
    super.dispose();
  }
}
