import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/errors/app_failure.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

enum ProductSegment { active, archived }

/// Products list state: live data, Active/Archived segment and name search.
class ProductListViewModel extends ChangeNotifier {
  ProductListViewModel(this._repository) {
    _subscribe();
  }

  final ProductRepository _repository;
  StreamSubscription<List<Product>>? _subscription;
  List<Product>? _all;
  String? _errorMessage;
  ProductSegment _segment = ProductSegment.active;
  String _query = '';

  bool get isLoading => _all == null && _errorMessage == null;
  String? get errorMessage => _errorMessage;
  ProductSegment get segment => _segment;
  String get query => _query;

  /// Products in the current segment that match the search text (anywhere in the name).
  List<Product> get visible {
    final needle = _query.trim().toLowerCase();
    return [
      for (final p in _all ?? const <Product>[])
        if (p.isActive == (_segment == ProductSegment.active) && (needle.isEmpty || p.name.toLowerCase().contains(needle)))
          p,
    ];
  }

  /// True when the user has no products at all (not just no matches).
  bool get hasNoProducts => (_all ?? const <Product>[]).isEmpty;

  void setSegment(ProductSegment segment) {
    _segment = segment;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void retry() {
    _errorMessage = null;
    _all = null;
    notifyListeners();
    _subscribe();
  }

  /// Returns an error message to show, or null on success.
  Future<String?> setActive(Product product, bool isActive) async {
    try {
      await _repository.setActive(product.id, isActive);
      return null;
    } on AppFailure catch (e) {
      return e.message;
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchAll().listen(
      (products) {
        _all = products;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error is AppFailure ? error.message : 'Could not load products. Please try again.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
