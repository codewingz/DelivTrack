import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';

/// Live list from a stream: loading, error + retry, and disposal. Subclasses add filtering.
abstract class LiveListViewModel<T> extends ChangeNotifier {
  LiveListViewModel(this._source) {
    _subscribe();
  }

  final Stream<List<T>> Function() _source;
  StreamSubscription<List<T>>? _subscription;
  List<T>? _items;
  String? _errorMessage;

  /// Everything the stream delivered (empty until the first event).
  List<T> get all => _items ?? const [];
  bool get isLoading => _items == null && _errorMessage == null;
  String? get errorMessage => _errorMessage;

  /// True when there is no data at all (not just no search matches).
  bool get hasNoItems => all.isEmpty;

  void retry() {
    _errorMessage = null;
    _items = null;
    notifyListeners();
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _source().listen(
      (items) {
        _items = items;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error is AppFailure
            ? error.message
            : 'Could not load data. Please try again.';
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
