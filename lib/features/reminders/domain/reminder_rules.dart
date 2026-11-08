import '../../../core/time/pakistan_time.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';

enum ReminderGroup {
  overdue('Overdue'),
  dueToday('Due today'),
  upcoming('Upcoming'),
  noDate('No date set');

  const ReminderGroup(this.label);
  final String label;
}

/// Which group a parcel's Pay Later reminder belongs to, or null when there is nothing to follow up:
/// only a Pay Later parcel that is not returned and still has an outstanding balance counts. A parcel
/// without a date is listed as unpaid and is never overdue. [today] is a Pakistan date "yyyy-MM-dd".
ReminderGroup? reminderGroupFor(Parcel parcel, String today) {
  if (parcel.method != CollectionMethod.payLater ||
      parcel.status == ParcelStatus.returned ||
      parcel.outstandingPaisa <= 0) {
    return null;
  }
  final date = parcel.estimatedPaymentDate;
  if (date == null) return ReminderGroup.noDate;
  final order = date.compareTo(today);
  if (order < 0) return ReminderGroup.overdue;
  return order == 0 ? ReminderGroup.dueToday : ReminderGroup.upcoming;
}

/// How a reminder's date reads: "Due today", "Overdue by 3 days · 7 Nov 2026", "Due 25 Dec 2026" or
/// "No date set". [today] is a Pakistan date.
String reminderDateText(Parcel parcel, ReminderGroup group, String today) {
  final date = parcel.estimatedPaymentDate;
  return switch (group) {
    ReminderGroup.noDate => 'No date set',
    ReminderGroup.dueToday => 'Due today',
    ReminderGroup.overdue => () {
      final days = daysBetween(date!, today);
      return 'Overdue by $days ${days == 1 ? 'day' : 'days'} · ${formatDate(date)}';
    }(),
    ReminderGroup.upcoming => 'Due ${formatDate(date!)}',
  };
}

/// Whole days between two "yyyy-MM-dd" dates ([later] minus [earlier]).
int daysBetween(String earlier, String later) =>
    DateTime.parse(later).difference(DateTime.parse(earlier)).inDays;

/// The Pay Later parcels to follow up, grouped. Overdue: longest overdue first; upcoming: soonest
/// first; no date: newest parcel first.
class Reminders {
  Reminders._(this._groups);

  factory Reminders.from(Iterable<Parcel> parcels, String today) {
    final groups = {
      for (final group in ReminderGroup.values) group: <Parcel>[],
    };
    for (final parcel in parcels) {
      final group = reminderGroupFor(parcel, today);
      if (group != null) groups[group]!.add(parcel);
    }
    int byDate(Parcel a, Parcel b) =>
        a.estimatedPaymentDate!.compareTo(b.estimatedPaymentDate!);
    groups[ReminderGroup.overdue]!.sort(byDate);
    groups[ReminderGroup.upcoming]!.sort(byDate);
    groups[ReminderGroup.noDate]!.sort(
      (a, b) => b.orderSequence.compareTo(a.orderSequence),
    );
    return Reminders._(groups);
  }

  final Map<ReminderGroup, List<Parcel>> _groups;

  List<Parcel> operator [](ReminderGroup group) => _groups[group]!;

  /// Due today plus overdue: what the bell badge counts.
  int get dueCount =>
      this[ReminderGroup.overdue].length + this[ReminderGroup.dueToday].length;

  bool get isEmpty => _groups.values.every((list) => list.isEmpty);
}
