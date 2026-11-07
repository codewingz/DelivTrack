import 'package:flutter/foundation.dart';
import '../errors/app_failure.dart';

/// Loading / error state for one submit action (sign up, save product, ...).
class ActionViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Runs [action]; returns true on success. Ignored while a request is running.
  Future<bool> run(Future<void> Function() action) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var success = false;
    try {
      await action();
      success = true;
    } on AppFailure catch (e) {
      _errorMessage = e.message;
    }
    _isLoading = false;
    if (!_disposed) notifyListeners();
    return success;
  }

  /// Shows [message] as the current error without running anything.
  void fail(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
