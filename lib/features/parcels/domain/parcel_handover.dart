import '../../../utils/postal_reference.dart';

/// The details recorded when a parcel is handed over (and corrected afterwards): the tracking number,
/// the delivery charge and, optionally, the packed weight. Any courier works; the tracking number is
/// all that identifies it. Handing a Draft over makes it Sent.
class ParcelHandover {
  const ParcelHandover({
    required this.postalReference,
    required this.deliveryChargePaisa,
    this.packedWeightGrams,
  });

  /// The tracking number, as typed.
  final String postalReference;
  final int? deliveryChargePaisa;
  final int? packedWeightGrams;

  /// Business-rule problems (empty when valid): the last line of defence before anything is written.
  List<String> problems() {
    final found = <String>[];
    if (postalReference.trim().isEmpty) {
      found.add('Enter the tracking number.');
    } else if (!isValidPostalReference(postalReference)) {
      found.add('Tracking number is not valid.');
    }
    if (deliveryChargePaisa == null || deliveryChargePaisa! < 0) {
      found.add('Enter the delivery charge from the slip.');
    }
    if (packedWeightGrams != null && packedWeightGrams! <= 0) {
      found.add('Enter a valid parcel weight.');
    }
    return found;
  }
}
