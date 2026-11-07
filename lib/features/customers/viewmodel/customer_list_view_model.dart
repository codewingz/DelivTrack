import '../../../core/view_models/live_list_view_model.dart';
import '../../../utils/phone.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Customers list state: live data plus search by name or phone number.
class CustomerListViewModel extends LiveListViewModel<Customer> {
  CustomerListViewModel(CustomerRepository repository) : super(repository.watchAll);

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
