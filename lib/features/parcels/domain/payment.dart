enum PaymentType {
  advance('advance', 'Advance'),
  postOfficeRemittance('post_office_remittance', 'Post office remittance'),
  customerPayment('customer_payment', 'Customer payment');

  const PaymentType(this.value, this.label);
  final String value;
  final String label;

  static PaymentType fromValue(String value) => values.firstWhere(
        (t) => t.value == value,
        orElse: () => throw StateError('Unknown payment type "$value"'),
      );
}

/// One payment received for a parcel (append-only).
class Payment {
  const Payment({required this.id, required this.amountPaisa, required this.type, required this.note, required this.receivedAt});

  final String id;
  final int amountPaisa;
  final PaymentType type;
  final String? note;
  final DateTime receivedAt;
}
