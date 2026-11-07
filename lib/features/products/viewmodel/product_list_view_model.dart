import '../../../core/errors/app_failure.dart';
import '../../../core/view_models/live_list_view_model.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

enum ProductSegment { active, archived }

/// Products list state: live data, Active/Archived segment and name search.
class ProductListViewModel extends LiveListViewModel<Product> {
  ProductListViewModel(this._repository) : super(_repository.watchAll);

  final ProductRepository _repository;
  ProductSegment _segment = ProductSegment.active;
  String _query = '';

  ProductSegment get segment => _segment;
  String get query => _query;

  /// Products in the current segment that match the search text (anywhere in the name).
  List<Product> get visible {
    final needle = _query.trim().toLowerCase();
    return [
      for (final p in all)
        if (p.isActive == (_segment == ProductSegment.active) && (needle.isEmpty || p.name.toLowerCase().contains(needle)))
          p,
    ];
  }

  void setSegment(ProductSegment segment) {
    _segment = segment;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
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
}
