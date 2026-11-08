enum CollectionMethod {
  postalCollection('postal_collection', 'Post office collection'),
  advance('advance', 'Advance paid'),

  /// Stored as "credit" for historical reasons; always shown as "Pay Later".
  payLater('credit', 'Pay Later'),
  giftFree('free_gift', 'Gift / Free');

  const CollectionMethod(this.value, this.label);
  final String value;
  final String label;

  static CollectionMethod fromValue(String value) => values.firstWhere(
    (m) => m.value == value,
    orElse: () => throw StateError('Unknown collection method "$value"'),
  );
}

/// How a returned parcel's payment review was settled. It only records the decision: nothing is
/// refunded, adjusted or deleted by completing the review.
enum ReviewResolution {
  refundGiven('refund_given', 'Refund given'),
  moneyKept('money_kept', 'Money kept'),
  balanceWaived('balance_waived', 'Balance not collected'),
  other('other', 'Other');

  const ReviewResolution(this.value, this.label);
  final String value;
  final String label;

  static ReviewResolution fromValue(String value) => values.firstWhere(
    (r) => r.value == value,
    orElse: () => throw StateError('Unknown review resolution "$value"'),
  );
}

enum ParcelStatus {
  draft('draft', 'Draft'),
  sent('sent', 'Sent'),
  returned('returned', 'Returned');

  const ParcelStatus(this.value, this.label);
  final String value;
  final String label;

  static ParcelStatus fromValue(String value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => throw StateError('Unknown parcel status "$value"'),
  );
}

enum PaymentStatus {
  notRequired('not_required', 'Not required'),
  pending('pending', 'Pending'),
  partial('partial', 'Partially paid'),
  received('received', 'Received');

  const PaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static PaymentStatus fromValue(String value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => throw StateError('Unknown payment status "$value"'),
  );
}
