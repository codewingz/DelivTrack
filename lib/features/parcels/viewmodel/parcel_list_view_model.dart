import '../../../core/errors/app_failure.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_search.dart';

/// The user's parcels, newest first, narrowed by a search text and filters, 20 rows at a time.
/// Searching and filtering run over every parcel (all of them are loaded), not just a page.
class ParcelListViewModel extends LiveListViewModel<Parcel> {
  ParcelListViewModel(this._repository, {this.clock = const Clock()}) : super(_repository.watchAll);

  static const pageSize = 20;

  final ParcelRepository _repository;
  final Clock clock;
  String _query = '';
  ParcelFilters _filters = ParcelFilters.none;
  int _pages = 1;

  Map<String, Set<String>>? _paymentDates;
  String? _paymentDatesError;
  int _lookup = 0;
  bool _disposed = false;

  String get query => _query;
  ParcelFilters get filters => _filters;
  String get today => pakistanDate(clock.nowUtc());
  bool get isNarrowed => _query.trim().isNotEmpty || !_filters.isEmpty;

  /// True while the payment dates the payment-date filter needs are still being fetched.
  bool get isLoadingPaymentDates => _filters.hasReceivedDates && _paymentDates == null && _paymentDatesError == null;

  /// A problem fetching those dates (the filter cannot be applied until it is retried).
  String? get paymentDatesError => _paymentDatesError;

  /// Products that appear on any parcel (archived ones included), by name, for the product filter.
  List<({String id, String name})> get products {
    final byId = <String, String>{};
    for (final parcel in all) {
      for (final item in parcel.items) {
        byId.putIfAbsent(item.productId, () => item.productName);
      }
    }
    return [for (final entry in byId.entries) (id: entry.key, name: entry.value)]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Every parcel that matches (before paging).
  List<Parcel> get matching {
    if (isLoadingPaymentDates || _paymentDatesError != null) return const [];
    final today = this.today;
    return [
      for (final parcel in all)
        if (parcelMatchesQuery(parcel, _query) && _filters.matches(parcel, today, paymentDates: _paymentDates?[parcel.id] ?? const {})) parcel,
    ];
  }

  /// The rows shown so far.
  List<Parcel> get visible => matching.take(_pages * pageSize).toList();

  bool get hasMore => matching.length > _pages * pageSize;

  void setQuery(String query) {
    _query = query;
    _pages = 1;
    notifyListeners();
  }

  void setFilters(ParcelFilters filters) {
    _filters = filters;
    _pages = 1;
    notifyListeners();
    if (filters.hasReceivedDates) _loadPaymentDates();
  }

  void clearAll() {
    _query = '';
    setFilters(ParcelFilters.none);
  }

  void loadMore() {
    _pages++;
    notifyListeners();
  }

  void retryPaymentDates() => _loadPaymentDates();

  Future<void> _loadPaymentDates() async {
    final mine = ++_lookup;
    _paymentDates = null;
    _paymentDatesError = null;
    notifyListeners();
    try {
      // Only a parcel that received money can have a payment date.
      final dates = await _repository.paymentDates([for (final parcel in all) if (parcel.receivedPaisa > 0) parcel.id]);
      if (_disposed || mine != _lookup) return;
      _paymentDates = dates;
    } on AppFailure catch (e) {
      if (_disposed || mine != _lookup) return;
      _paymentDatesError = e.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
