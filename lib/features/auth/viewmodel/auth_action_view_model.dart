import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

/// Loading / error state for one auth submit (sign up, log in, reset email...).
class AuthActionViewModel extends ChangeNotifier {
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
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
    }
    _isLoading = false;
    if (!_disposed) notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
