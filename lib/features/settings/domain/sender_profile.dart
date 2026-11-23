import '../../../utils/text.dart';

/// Business/sender information used on parcel shipping slips, return labels, and invoices.
class SenderProfile {
  const SenderProfile({
    required this.name,
    required this.phone,
    required this.address,
    this.businessName = '',
  });

  const SenderProfile.empty()
    : name = '',
      phone = '',
      address = '',
      businessName = '';

  final String name;
  final String phone;
  final String address;

  /// Optional shop or company name; empty when not given.
  final String businessName;

  Map<String, dynamic> toMap() => {
    'name': collapseSpaces(name),
    'phone': collapseSpaces(phone),
    'address': collapseSpaces(address),
    if (collapseSpaces(businessName).isNotEmpty)
      'businessName': collapseSpaces(businessName),
  };

  factory SenderProfile.fromMap(Map<String, dynamic> map) {
    return SenderProfile(
      name: (map['name'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      businessName: (map['businessName'] as String?)?.trim() ?? '',
    );
  }

  SenderProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? businessName,
  }) => SenderProfile(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    businessName: businessName ?? this.businessName,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenderProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          address == other.address &&
          businessName == other.businessName;

  @override
  int get hashCode => Object.hash(name, phone, address, businessName);
}
