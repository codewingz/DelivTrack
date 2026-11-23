import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../parcels/domain/parcel.dart';
import 'reminder_rules.dart';

/// One notification to show on the phone for a Pay Later parcel.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.parcelId,
    required this.instantUtc,
    required this.title,
    required this.body,
  });

  /// Stable per parcel (its order sequence), so scheduling again replaces instead of duplicating.
  final int id;
  final String parcelId;
  final DateTime instantUtc;
  final String title;

  /// Order number, customer name and the amount left. Never the address (lock-screen privacy).
  final String body;

  /// Parcel id first (it opens that parcel when tapped); the rest tells a change from "unchanged".
  String get payload =>
      '$parcelId|${instantUtc.millisecondsSinceEpoch}|$title|$body';
}

/// The parcel a notification payload opens.
String parcelIdFromPayload(String payload) => payload.split('|').first;

/// Reminders the phone should hold for [parcels] at [nowUtc]: Pay Later parcels with a date of today or
/// later that still owe money, at [minutesOfDay] (Pakistan time, 9:00 AM unless the owner chose
/// another time in Settings) on that date. A time that has already passed is
/// skipped (the in-app list shows it), so nothing is shown twice.
List<PlannedReminder> plannedReminders(
  Iterable<Parcel> parcels,
  DateTime nowUtc, {
  int minutesOfDay = 9 * 60,
}) {
  final today = pakistanDate(nowUtc);
  final planned = <PlannedReminder>[];
  for (final parcel in parcels) {
    final group = reminderGroupFor(parcel, today);
    if (group != ReminderGroup.dueToday && group != ReminderGroup.upcoming) {
      continue;
    }
    final date = parcel.estimatedPaymentDate!;
    final parts = date.split('-').map(int.parse).toList();
    // Pakistan is UTC+5 with no daylight saving.
    final instant = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
    ).add(Duration(minutes: minutesOfDay - 5 * 60));
    if (!instant.isAfter(nowUtc)) continue;
    planned.add(
      PlannedReminder(
        id: parcel.orderSequence,
        parcelId: parcel.id,
        instantUtc: instant,
        title: 'Payment due: ${parcel.orderNumber}',
        body:
            '${parcel.customerName} · ${formatRupees(parcel.outstandingPaisa)} remaining · due ${formatDate(date)}',
      ),
    );
  }
  return planned;
}
