import 'dart:async';
import 'package:flutter/foundation.dart';

/// Notifies listeners on every stream event (used as go_router's refreshListenable).
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
