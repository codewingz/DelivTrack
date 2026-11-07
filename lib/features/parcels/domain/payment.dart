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
  const Payment({
    required this.id,
    required this.amountPaisa,
    required this.type,
    required this.note,
    required this.receivedAt,
    this.reversalOfPaymentId,
    this.correctionReason,
    this.correctionOfPaymentId,
  });

  final String id;
  final int amountPaisa;
  final PaymentType type;
  final String? note;
  final DateTime receivedAt;

  /// Set on the negative twin that cancels an earlier payment, with the reason given.
  final String? reversalOfPaymentId;
  final String? correctionReason;

  /// Set on the payment that replaces a corrected one.
  final String? correctionOfPaymentId;

  bool get isReversal => reversalOfPaymentId != null;
}
