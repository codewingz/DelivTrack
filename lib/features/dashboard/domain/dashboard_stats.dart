import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../parcels/domain/parcel_search.dart';
import '../../reminders/domain/reminder_rules.dart';

/// The list each count card opens: the card's number is exactly the number of parcels that list shows.
abstract final class DashboardLists {
  static const all = ParcelFilters.none;
  static const sent = ParcelFilters(statuses: {ParcelStatus.sent});
  static const returned = ParcelFilters(statuses: {ParcelStatus.returned});
  static const freeGift = ParcelFilters(methods: {CollectionMethod.giftFree});
  static const paymentReceived = ParcelFilters(payments: {PaymentFilter.partial, PaymentFilter.received});
  static const pendingPayment = ParcelFilters(payments: {PaymentFilter.pending});
}

/// The dashboard figures for a user's parcels.
///
/// * A "received" count is a count of parcels, never a sum of payment transactions.
/// * Gift / Free parcels expect nothing, so they never add to what is outstanding.
/// * Money already received on a returned parcel stays in Total received (nothing is refunded
///   automatically); what a returned parcel still owes is not counted as outstanding. Such parcels are
///   counted under [needsReview] instead, so they are never silently dropped.
/// * An Advance parcel's money is received once; it is not also an extra receivable.
class DashboardStats {
  const DashboardStats({
    required this.totalParcels,
    required this.sent,
    required this.returned,
    required this.freeGift,
    required this.paymentReceived,
    required this.pendingPayment,
    required this.totalReceivedPaisa,
    required this.totalOutstandingPaisa,
    required this.payLaterBalancePaisa,
    required this.advancePaisa,
    required this.needsReview,
    required this.dueToday,
    required this.overdue,
    required this.recent,
  });

  /// [everyParcel] may include archived parcels. Archiving is organisational, not a financial event, so
  /// the money received stays in "Total received" and "Advance amount"; every count, list, balance and
  /// reminder covers the active (not archived) parcels only.
  factory DashboardStats.from(List<Parcel> everyParcel, String today) {
    final parcels = [for (final parcel in everyParcel) if (!parcel.isArchived) parcel];
    int count(ParcelFilters list) => parcels.where((parcel) => list.matches(parcel, today)).length;
    var received = 0;
    var outstanding = 0;
    var payLater = 0;
    var advance = 0;
    for (final parcel in everyParcel) {
      received += parcel.receivedPaisa;
      if (parcel.method == CollectionMethod.advance) advance += parcel.receivedPaisa;
    }
    for (final parcel in parcels) {
      if (parcel.method == CollectionMethod.giftFree || parcel.status == ParcelStatus.returned) continue;
      outstanding += parcel.outstandingPaisa;
      if (parcel.method == CollectionMethod.payLater) payLater += parcel.outstandingPaisa;
    }
    final reminders = Reminders.from(parcels, today);
    final newestFirst = [...parcels]..sort((a, b) => b.orderSequence.compareTo(a.orderSequence));
    return DashboardStats(
      totalParcels: parcels.length,
      sent: count(DashboardLists.sent),
      returned: count(DashboardLists.returned),
      freeGift: count(DashboardLists.freeGift),
      paymentReceived: count(DashboardLists.paymentReceived),
      pendingPayment: count(DashboardLists.pendingPayment),
      totalReceivedPaisa: received,
      totalOutstandingPaisa: outstanding,
      payLaterBalancePaisa: payLater,
      advancePaisa: advance,
      needsReview: parcels.where((parcel) => parcel.paymentReviewRequired).length,
      dueToday: reminders[ReminderGroup.dueToday].length,
      overdue: reminders[ReminderGroup.overdue].length,
      recent: newestFirst.take(5).toList(),
    );
  }

  final int totalParcels;
  final int sent;
  final int returned;
  final int freeGift;
  final int paymentReceived;
  final int pendingPayment;
  final int totalReceivedPaisa;
  final int totalOutstandingPaisa;
  final int payLaterBalancePaisa;
  final int advancePaisa;
  final int needsReview;
  final int dueToday;
  final int overdue;
  final List<Parcel> recent;
}
