import '../../../utils/phone.dart';
import '../../../utils/postal_reference.dart';
import 'parcel.dart';
import 'parcel_enums.dart';

/// Whether [parcel] matches what the user typed: any part of the order number, the postal reference
/// (spaces and case ignored), the customer's name or phone number, or a product name.
bool parcelMatchesQuery(Parcel parcel, String query) {
  final needle = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (needle.isEmpty) return true;
  if (parcel.orderNumber.toLowerCase().contains(needle)) return true;
  if (parcel.customerName.toLowerCase().contains(needle)) return true;
  if (parcel.items.any((item) => item.productName.toLowerCase().contains(needle))) return true;
  final reference = normalizePostalReference(needle);
  if (reference.isNotEmpty && normalizePostalReference(parcel.postalReference).contains(reference)) return true;
  final digits = phoneSearchDigits(needle);
  return digits.length >= 3 && normalizePhone(parcel.customerPhone).contains(digits);
}

/// How a parcel's payment is described in the filter (overdue is its own state).
enum PaymentFilter {
  pending('Pending'),
  partial('Partially paid'),
  received('Received'),
  notRequired('Not required'),
  overdue('Overdue');

  const PaymentFilter(this.label);
  final String label;
}

/// The filters of the parcel list. Choices within one group are alternatives (any may match); the
/// groups all have to match. Dates are "yyyy-MM-dd" Pakistan dates, both ends included.
class ParcelFilters {
  const ParcelFilters({
    this.sendingFrom,
    this.sendingTo,
    this.receivedFrom,
    this.receivedTo,
    this.productId,
    this.productName,
    this.methods = const {},
    this.payments = const {},
    this.statuses = const {},
  });

  static const none = ParcelFilters();

  final String? sendingFrom;
  final String? sendingTo;
  final String? receivedFrom;
  final String? receivedTo;
  final String? productId;
  final String? productName;
  final Set<CollectionMethod> methods;
  final Set<PaymentFilter> payments;
  final Set<ParcelStatus> statuses;

  bool get hasSendingDates => sendingFrom != null || sendingTo != null;
  bool get hasReceivedDates => receivedFrom != null || receivedTo != null;

  /// How many filter groups are set (what the badge shows).
  int get activeCount => [hasSendingDates, hasReceivedDates, productId != null, methods.isNotEmpty, payments.isNotEmpty, statuses.isNotEmpty].where((on) => on).length;

  bool get isEmpty => activeCount == 0;

  ParcelFilters copyWith({
    Object? sendingFrom = _keep,
    Object? sendingTo = _keep,
    Object? receivedFrom = _keep,
    Object? receivedTo = _keep,
    Object? productId = _keep,
    Object? productName = _keep,
    Set<CollectionMethod>? methods,
    Set<PaymentFilter>? payments,
    Set<ParcelStatus>? statuses,
  }) =>
      ParcelFilters(
        sendingFrom: identical(sendingFrom, _keep) ? this.sendingFrom : sendingFrom as String?,
        sendingTo: identical(sendingTo, _keep) ? this.sendingTo : sendingTo as String?,
        receivedFrom: identical(receivedFrom, _keep) ? this.receivedFrom : receivedFrom as String?,
        receivedTo: identical(receivedTo, _keep) ? this.receivedTo : receivedTo as String?,
        productId: identical(productId, _keep) ? this.productId : productId as String?,
        productName: identical(productName, _keep) ? this.productName : productName as String?,
        methods: methods ?? this.methods,
        payments: payments ?? this.payments,
        statuses: statuses ?? this.statuses,
      );

  static const Object _keep = Object();

  /// Why the choices cannot work together (a range that ends before it starts), or null.
  String? get problem {
    if (sendingFrom != null && sendingTo != null && sendingTo!.compareTo(sendingFrom!) < 0) return 'The sending date range ends before it starts.';
    if (receivedFrom != null && receivedTo != null && receivedTo!.compareTo(receivedFrom!) < 0) return 'The payment date range ends before it starts.';
    return null;
  }

  /// [paymentDates] are the Pakistan dates this parcel received money on (needed only for the
  /// payment-date filter). [today] is a Pakistan date.
  bool matches(Parcel parcel, String today, {Set<String> paymentDates = const {}}) {
    if (sendingFrom != null && parcel.sendingDate.compareTo(sendingFrom!) < 0) return false;
    if (sendingTo != null && parcel.sendingDate.compareTo(sendingTo!) > 0) return false;
    if (hasReceivedDates && !paymentDates.any((date) => (receivedFrom == null || date.compareTo(receivedFrom!) >= 0) && (receivedTo == null || date.compareTo(receivedTo!) <= 0))) {
      return false;
    }
    if (productId != null && !parcel.items.any((item) => item.productId == productId)) return false;
    if (methods.isNotEmpty && !methods.contains(parcel.method)) return false;
    if (statuses.isNotEmpty && !statuses.contains(parcel.status)) return false;
    if (payments.isNotEmpty && !payments.any((filter) => _paymentMatches(filter, parcel, today))) return false;
    return true;
  }

  static bool _paymentMatches(PaymentFilter filter, Parcel parcel, String today) => switch (filter) {
        PaymentFilter.pending => parcel.paymentStatus == PaymentStatus.pending,
        PaymentFilter.partial => parcel.paymentStatus == PaymentStatus.partial,
        PaymentFilter.received => parcel.paymentStatus == PaymentStatus.received,
        PaymentFilter.notRequired => parcel.paymentStatus == PaymentStatus.notRequired,
        PaymentFilter.overdue => parcel.method == CollectionMethod.payLater &&
            parcel.status != ParcelStatus.returned &&
            parcel.outstandingPaisa > 0 &&
            parcel.estimatedPaymentDate != null &&
            parcel.estimatedPaymentDate!.compareTo(today) < 0,
      };
}
