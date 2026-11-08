import '../../../utils/phone.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.phone2 = '',
    this.businessDetails = '',
  });

  final String id;
  final String name;

  /// As the user typed it (shown in the UI).
  final String phone;
  final String address;

  /// Optional second number; empty when there is none.
  final String phone2;

  /// Optional free text about the customer's business; empty when there is none.
  final String businessDetails;

  /// Digits-only form used for duplicate detection and search.
  String get phoneNormalized => normalizePhone(phone);
}
