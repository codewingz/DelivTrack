import 'dart:async';
import '../../../core/view_models/live_list_view_model.dart';
import '../../../utils/phone.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../../payments/domain/payment_tabs.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// What a customer's row shows besides the contact details.
typedef CustomerFigures = ({int parcels, int outstandingPaisa});

/// Customers list state: live data, search by name or phone number, and each customer's parcel count
/// and outstanding balance (from the live parcels).
class CustomerListViewModel extends LiveListViewModel<Customer> {
  /// [parcelRepository] is only needed where the figures are shown (the Customers tab); the customer
  /// picker leaves it out.
  CustomerListViewModel(CustomerRepository repository, [ParcelRepository? parcelRepository]) : super(repository.watchAll) {
    _parcels = parcelRepository?.watchAll().listen(
      (parcels) {
        _figures = _figuresFor(parcels);
        notifyListeners();
      },
      // The list itself still works without the figures.
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<List<Parcel>>? _parcels;
  Map<String, CustomerFigures> _figures = const {};

  static Map<String, CustomerFigures> _figuresFor(List<Parcel> parcels) {
    final byCustomer = <String, List<Parcel>>{};
    for (final parcel in parcels) {
      (byCustomer[parcel.customerId] ??= []).add(parcel);
    }
    return {for (final entry in byCustomer.entries) entry.key: (parcels: entry.value.length, outstandingPaisa: PaymentTotals.from(entry.value).outstandingPaisa)};
  }

  /// Parcel count and outstanding balance of [customerId] (zeros when there are no parcels).
  CustomerFigures figuresOf(String customerId) => _figures[customerId] ?? (parcels: 0, outstandingPaisa: 0);

  @override
  void dispose() {
    _parcels?.cancel();
    super.dispose();
  }

  String _query = '';

  String get query => _query;

  /// Customers whose name contains the text, or whose phone contains the typed digits.
  List<Customer> get visible {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    final digits = phoneSearchDigits(needle);
    return [
      for (final c in all)
        if (c.name.toLowerCase().contains(needle) || (digits.isNotEmpty && c.phoneNormalized.contains(digits))) c,
    ];
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }
}
