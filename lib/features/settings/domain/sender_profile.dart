import '../../../utils/text.dart';

/// Business/sender information used on parcel shipping slips, return labels, and invoices.
class SenderProfile {
  const SenderProfile({
    required this.name,
    required this.phone,
    required this.address,
    this.businessName = '',
    this.preferSenderName = false,
    this.invoiceUsesSenderName = false,
    this.labelUsesSenderName = false,
  });

  const SenderProfile.empty()
    : name = '',
      phone = '',
      address = '',
      businessName = '',
      preferSenderName = false,
      invoiceUsesSenderName = false,
      labelUsesSenderName = false;

  final String name;
  final String phone;
  final String address;

  /// Optional shop or company name; empty when not given.
  final String businessName;

  /// The owner's choice of the name customers see in WhatsApp messages: the
  /// business name by default, the sender name when true.
  final bool preferSenderName;

  /// The name shown to customers: the business name, unless the owner chose
  /// the sender name or gave no business name. Empty when nothing is saved.
  String get customerFacingName => _nameFor(preferSenderName);

  /// The same choice, made separately for invoices and for printed labels.
  final bool invoiceUsesSenderName;
  final bool labelUsesSenderName;

  /// The name printed on invoices.
  String get invoiceName => _nameFor(invoiceUsesSenderName);

  /// The name printed on shipping labels.
  String get labelName => _nameFor(labelUsesSenderName);

  String _nameFor(bool useSenderName) =>
      !useSenderName && businessName.isNotEmpty ? businessName : name;

  Map<String, dynamic> toMap() => {
    'name': collapseSpaces(name),
    'phone': collapseSpaces(phone),
    'address': collapseSpaces(address),
    if (collapseSpaces(businessName).isNotEmpty)
      'businessName': collapseSpaces(businessName),
    if (preferSenderName) 'preferSenderName': true,
    if (invoiceUsesSenderName) 'invoiceUsesSenderName': true,
    if (labelUsesSenderName) 'labelUsesSenderName': true,
  };

  factory SenderProfile.fromMap(Map<String, dynamic> map) {
    return SenderProfile(
      name: (map['name'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      businessName: (map['businessName'] as String?)?.trim() ?? '',
      preferSenderName: map['preferSenderName'] == true,
      invoiceUsesSenderName: map['invoiceUsesSenderName'] == true,
      labelUsesSenderName: map['labelUsesSenderName'] == true,
    );
  }

  SenderProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? businessName,
    bool? preferSenderName,
    bool? invoiceUsesSenderName,
    bool? labelUsesSenderName,
  }) => SenderProfile(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    businessName: businessName ?? this.businessName,
    preferSenderName: preferSenderName ?? this.preferSenderName,
    invoiceUsesSenderName: invoiceUsesSenderName ?? this.invoiceUsesSenderName,
    labelUsesSenderName: labelUsesSenderName ?? this.labelUsesSenderName,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenderProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          address == other.address &&
          businessName == other.businessName &&
          preferSenderName == other.preferSenderName &&
          invoiceUsesSenderName == other.invoiceUsesSenderName &&
          labelUsesSenderName == other.labelUsesSenderName;

  @override
  int get hashCode => Object.hash(
    name,
    phone,
    address,
    businessName,
    preferSenderName,
    invoiceUsesSenderName,
    labelUsesSenderName,
  );
}
