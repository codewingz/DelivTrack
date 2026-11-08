import 'parcel_enums.dart';

/// What is still to be collected: never negative.
int outstandingFor({required int expectedPaisa, required int receivedPaisa}) =>
    expectedPaisa > receivedPaisa ? expectedPaisa - receivedPaisa : 0;

PaymentStatus paymentStatusFor({
  required bool isFree,
  required int expectedPaisa,
  required int receivedPaisa,
}) {
  if (isFree) return PaymentStatus.notRequired;
  if (expectedPaisa > 0 && receivedPaisa >= expectedPaisa) {
    return PaymentStatus.received;
  }
  if (receivedPaisa > 0) return PaymentStatus.partial;
  return PaymentStatus.pending;
}

const maxPaymentNoteLength = 200;

/// Why a payment can't be recorded (before looking at the parcel), or null when it is fine.
String? paymentProblem({required int amountPaisa, required String note}) {
  if (amountPaisa <= 0) return 'Enter an amount.';
  if (note.length > maxPaymentNoteLength) {
    return 'Use at most $maxPaymentNoteLength characters.';
  }
  return null;
}
