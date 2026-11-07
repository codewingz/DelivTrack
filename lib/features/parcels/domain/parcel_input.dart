import '../../customers/domain/customer.dart';
import 'parcel_enums.dart';
import 'parcel_item.dart';
import '../../../utils/postal_reference.dart';

const maxParcelItems = 20;

/// Everything the user enters for a parcel (used for both create and edit).
class ParcelInput {
  const ParcelInput({
    required this.customer,
    required this.items,
    required this.method,
    required this.service,
    this.otherServiceName,
    this.postalReference = '',
    this.deliveryChargePaisa,
    this.packedWeightGrams,
    this.estimatedPaymentDate,
    required this.status,
  });

  final Customer customer;
  final List<ParcelItem> items;
  final CollectionMethod method;
  final PostalService service;

  /// Required when [service] is "Other".
  final String? otherServiceName;

  /// As typed; empty for a draft without a slip yet.
  final String postalReference;
  final int? deliveryChargePaisa;
  final int? packedWeightGrams;

  /// "yyyy-MM-dd"; only for Pay Later.
  final String? estimatedPaymentDate;
  final ParcelStatus status;

  /// Free/gift parcels expect no payment whatever the prices say.
  int get expectedPaisa => method == CollectionMethod.giftFree ? 0 : items.fold(0, (sum, i) => sum + i.lineTotalPaisa);

  /// Business-rule problems (empty list when the input is valid). The form shows field-level
  /// messages; this is the last line of defence before anything is written.
  List<String> problems({String? today}) {
    final found = <String>[];
    if (items.isEmpty) found.add('Add at least one product.');
    if (items.length > maxParcelItems) found.add('A parcel can have at most $maxParcelItems products.');
    if (items.map((i) => i.productId).toSet().length != items.length) found.add('The same product is added twice.');
    if (method != CollectionMethod.giftFree && items.any((i) => i.unitPricePaisa <= 0)) found.add('Every product needs an agreed price.');
    if (method != CollectionMethod.giftFree && items.isNotEmpty && expectedPaisa <= 0) found.add('The products total must be above zero.');
    if (service == PostalService.other && (otherServiceName ?? '').trim().length < 2) found.add('Enter the postal service name.');
    if (service != PostalService.other && otherServiceName != null) found.add('A service name is only for "Other".');
    if (postalReference.trim().isNotEmpty && !isValidPostalReference(postalReference)) found.add('Postal reference is not valid.');
    if (status == ParcelStatus.sent && postalReference.trim().isEmpty) found.add('A sent parcel needs its postal reference.');
    if (status == ParcelStatus.sent && deliveryChargePaisa == null) found.add('A sent parcel needs its delivery charge.');
    if (status == ParcelStatus.returned) found.add('A new parcel cannot start as returned.');
    if (estimatedPaymentDate != null) {
      if (method != CollectionMethod.payLater) found.add('A payment date is only for Pay Later parcels.');
      if (today != null && estimatedPaymentDate!.compareTo(today) < 0) found.add('The payment date cannot be in the past.');
    }
    return found;
  }
}
