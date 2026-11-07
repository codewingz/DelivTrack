import '../../../utils/phone.dart';

class Customer {
  const Customer({required this.id, required this.name, required this.phone, required this.address});

  final String id;
  final String name;

  /// As the user typed it (shown in the UI).
  final String phone;
  final String address;

  /// Digits-only form used for duplicate detection and search.
  String get phoneNormalized => normalizePhone(phone);
}
