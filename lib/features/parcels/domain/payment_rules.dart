import 'parcel_enums.dart';

/// What is still to be collected: never negative.
int outstandingFor({required int expectedPaisa, required int receivedPaisa}) =>
    expectedPaisa > receivedPaisa ? expectedPaisa - receivedPaisa : 0;

PaymentStatus paymentStatusFor({required bool isFree, required int expectedPaisa, required int receivedPaisa}) {
  if (isFree) return PaymentStatus.notRequired;
  if (expectedPaisa > 0 && receivedPaisa >= expectedPaisa) return PaymentStatus.received;
  if (receivedPaisa > 0) return PaymentStatus.partial;
  return PaymentStatus.pending;
}
