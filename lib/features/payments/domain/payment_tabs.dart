import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';

/// The lists on the Payments screen. Gift / Free parcels are never listed (nothing is expected), and
/// returned parcels only appear under Review.
enum PaymentTab {
  pending('Pending'),
  partial('Partially paid'),
  received('Received'),
  postOffice('Post office'),
  advance('Advance'),
  payLater('Pay Later'),
  overdue('Overdue'),
  review('Review');

  const PaymentTab(this.label);
  final String label;

  /// Whether [parcel] belongs in this list. [today] is a Pakistan date "yyyy-MM-dd".
  bool includes(Parcel parcel, String today) {
    if (parcel.method == CollectionMethod.giftFree) return false;
    if (parcel.status == ParcelStatus.returned) {
      return this == review && parcel.paymentReviewRequired;
    }
    return switch (this) {
      pending => parcel.paymentStatus == PaymentStatus.pending,
      partial => parcel.paymentStatus == PaymentStatus.partial,
      received => parcel.paymentStatus == PaymentStatus.received,
      postOffice => parcel.method == CollectionMethod.postalCollection,
      advance => parcel.method == CollectionMethod.advance,
      payLater =>
        parcel.method == CollectionMethod.payLater &&
            parcel.outstandingPaisa > 0,
      // No date: unpaid, but never overdue.
      overdue =>
        parcel.method == CollectionMethod.payLater &&
            parcel.outstandingPaisa > 0 &&
            parcel.estimatedPaymentDate != null &&
            parcel.estimatedPaymentDate!.compareTo(today) < 0,
      review => false,
    };
  }
}

/// The three header figures (Gift / Free and returned parcels are left out).
class PaymentTotals {
  const PaymentTotals({
    required this.outstandingPaisa,
    required this.payLaterPaisa,
    required this.advancePaisa,
  });

  factory PaymentTotals.from(Iterable<Parcel> parcels) {
    var outstanding = 0;
    var payLater = 0;
    var advance = 0;
    for (final parcel in parcels) {
      if (parcel.method == CollectionMethod.giftFree ||
          parcel.status == ParcelStatus.returned) {
        continue;
      }
      outstanding += parcel.outstandingPaisa;
      if (parcel.method == CollectionMethod.payLater) {
        payLater += parcel.outstandingPaisa;
      }
      if (parcel.method == CollectionMethod.advance) {
        advance += parcel.receivedPaisa;
      }
    }
    return PaymentTotals(
      outstandingPaisa: outstanding,
      payLaterPaisa: payLater,
      advancePaisa: advance,
    );
  }

  /// Still to be collected on every paid-type parcel.
  final int outstandingPaisa;

  /// The part of that owed on Pay Later parcels.
  final int payLaterPaisa;

  /// Received so far on Advance parcels.
  final int advancePaisa;
}
