import '../../../utils/postal_reference.dart';
import 'parcel_enums.dart';

/// The post-office details recorded when a parcel is handed over (and corrected afterwards): the
/// service, the reference printed on the slip, the delivery charge and, optionally, the packed weight.
/// Handing a Draft over makes it Sent.
class ParcelHandover {
  const ParcelHandover({
    required this.service,
    this.otherServiceName,
    required this.postalReference,
    required this.deliveryChargePaisa,
    this.packedWeightGrams,
  });

  final PostalService service;

  /// Required when [service] is "Other".
  final String? otherServiceName;

  /// As typed on the slip.
  final String postalReference;
  final int? deliveryChargePaisa;
  final int? packedWeightGrams;

  /// Business-rule problems (empty when valid): the last line of defence before anything is written.
  List<String> problems() {
    final found = <String>[];
    if (postalReference.trim().isEmpty) {
      found.add('Enter the postal reference from the slip.');
    } else if (!isValidPostalReference(postalReference)) {
      found.add('Postal reference is not valid.');
    }
    if (deliveryChargePaisa == null || deliveryChargePaisa! < 0) {
      found.add('Enter the delivery charge from the slip.');
    }
    if (service == PostalService.other &&
        (otherServiceName ?? '').trim().length < 2) {
      found.add('Enter the postal service name.');
    }
    if (service != PostalService.other && otherServiceName != null) {
      found.add('A service name is only for "Other".');
    }
    if (packedWeightGrams != null && packedWeightGrams! <= 0) {
      found.add('Enter a valid parcel weight.');
    }
    return found;
  }
}
