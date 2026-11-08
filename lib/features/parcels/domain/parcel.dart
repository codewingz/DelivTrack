import '../../../core/time/pakistan_time.dart';
import 'parcel_enums.dart';
import 'parcel_item.dart';
import 'payment_rules.dart';

/// A saved parcel as read from Firestore.
class Parcel {
  const Parcel({
    required this.id,
    required this.orderNumber,
    required this.orderSequence,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.method,
    required this.service,
    required this.otherServiceName,
    required this.postalReference,
    required this.deliveryChargePaisa,
    required this.packedWeightGrams,
    required this.sendingDate,
    required this.estimatedPaymentDate,
    required this.expectedPaisa,
    required this.receivedPaisa,
    required this.outstandingPaisa,
    required this.paymentStatus,
    required this.status,
    this.notes,
    this.returnedDate,
    this.returnReason,
    this.paymentReviewRequired = false,
    this.reviewResolution,
    this.reviewNote,
    this.reviewDate,
    this.lastPaymentId,
    this.isArchived = false,
  });

  /// Reads many stored documents: the parcels that can be read (in the given order) and the ids of the
  /// documents that can not, so one damaged document never hides the others.
  static ({List<Parcel> parcels, List<String> unreadableIds}) readAll(Iterable<MapEntry<String, Map<String, dynamic>>> documents) {
    final parcels = <Parcel>[];
    final unreadable = <String>[];
    for (final document in documents) {
      final parcel = tryFromMap(document.key, document.value);
      if (parcel == null) {
        unreadable.add(document.key);
      } else {
        parcels.add(parcel);
      }
    }
    return (parcels: parcels, unreadableIds: unreadable);
  }

  /// The parcel stored in [data], or null when the document can't be read: a missing field, a value of
  /// the wrong type or an unknown status, or money that is negative or does not add up. Nothing is
  /// guessed or repaired, so an invalid amount never becomes a valid one.
  static Parcel? tryFromMap(String id, Map<String, dynamic> data) {
    try {
      final parcel = Parcel.fromMap(id, data);
      final moneyAddsUp = parcel.expectedPaisa >= 0 &&
          parcel.receivedPaisa >= 0 &&
          parcel.outstandingPaisa == outstandingFor(expectedPaisa: parcel.expectedPaisa, receivedPaisa: parcel.receivedPaisa);
      return moneyAddsUp ? parcel : null;
    } on TypeError {
      return null;
    } on StateError {
      return null;
    }
  }

  factory Parcel.fromMap(String id, Map<String, dynamic> data) {
    final customer = data['customerSnapshot'] as Map<String, dynamic>;
    return Parcel(
      id: id,
      orderNumber: data['orderNumber'] as String,
      orderSequence: data['orderSequence'] as int,
      customerId: data['customerId'] as String,
      customerName: customer['name'] as String,
      customerPhone: customer['phone'] as String,
      customerAddress: customer['address'] as String,
      items: [for (final item in data['items'] as List<dynamic>) ParcelItem.fromMap(Map<String, dynamic>.from(item as Map))],
      method: CollectionMethod.fromValue(data['collectionMethod'] as String),
      service: PostalService.fromValue(data['postalServiceType'] as String),
      otherServiceName: data['otherPostalServiceName'] as String?,
      postalReference: data['postalReference'] as String,
      deliveryChargePaisa: data['deliveryChargePaisa'] as int?,
      packedWeightGrams: data['actualPackedWeightGrams'] as int?,
      sendingDate: data['sendingDateLocal'] as String,
      estimatedPaymentDate: data['estimatedPaymentDateLocal'] as String?,
      expectedPaisa: data['productAmountExpectedPaisa'] as int,
      receivedPaisa: data['receivedPaisa'] as int,
      outstandingPaisa: data['outstandingPaisa'] as int,
      paymentStatus: PaymentStatus.fromValue(data['paymentStatus'] as String),
      status: ParcelStatus.fromValue(data['parcelStatus'] as String),
      notes: data['notes'] as String?,
      returnedDate: data['returnedDateLocal'] as String?,
      returnReason: data['returnReason'] as String?,
      paymentReviewRequired: data['paymentReviewRequired'] as bool? ?? false,
      reviewResolution: data['paymentReviewReason'] == null ? null : ReviewResolution.fromValue(data['paymentReviewReason'] as String),
      reviewNote: data['paymentReviewNote'] as String?,
      reviewDate: data['paymentReviewDateLocal'] as String?,
      lastPaymentId: data['lastPaymentId'] as String?,
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  final String id;
  final String orderNumber;
  final int orderSequence;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<ParcelItem> items;
  final CollectionMethod method;
  final PostalService service;
  final String? otherServiceName;
  final String postalReference;
  final int? deliveryChargePaisa;
  final int? packedWeightGrams;

  /// "yyyy-MM-dd" (Pakistan date), set once when the parcel is created.
  final String sendingDate;
  final String? estimatedPaymentDate;
  final int expectedPaisa;
  final int receivedPaisa;
  final int outstandingPaisa;
  final PaymentStatus paymentStatus;
  final ParcelStatus status;
  final String? notes;

  /// "yyyy-MM-dd"; only on a returned parcel.
  final String? returnedDate;
  final String? returnReason;

  /// A returned parcel that received or still owes money: nothing is refunded automatically.
  final bool paymentReviewRequired;

  /// Set when the review was completed (then [paymentReviewRequired] is false): how it was settled,
  /// the required note and the "yyyy-MM-dd" date of the decision.
  final ReviewResolution? reviewResolution;
  final String? reviewNote;
  final String? reviewDate;

  bool get paymentReviewCompleted => reviewResolution != null;

  /// The payment or reversal that last moved this parcel's money (every payment, correction and
  /// date-only correction changes it), so "received + this" says whether the payments changed.
  final String? lastPaymentId;

  /// Changes whenever the parcel's payment history changes (used to know when cached payments are stale).
  String get paymentsSignature => '$receivedPaisa|${lastPaymentId ?? ''}';

  /// Hidden from every list and total; the order number stays reserved. Only restoring is possible.
  final bool isArchived;

  /// A parcel can be archived once nothing is left to chase: a draft, a returned parcel, or one that
  /// owes nothing (paid in full, or Gift / Free). A returned parcel whose payment review is still open
  /// stays on the lists until the review is completed.
  bool get canArchive => !isArchived && !paymentReviewRequired && (status != ParcelStatus.sent || outstandingPaisa == 0);

  /// The service as shown: the typed name for "Other", otherwise VPP / VPL / VPR.
  String get serviceLabel => service == PostalService.other ? (otherServiceName ?? 'Other') : service.value;

  String get sendingDateLabel => formatDate(sendingDate);
}
