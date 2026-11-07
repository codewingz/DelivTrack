import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

// 7:30 AM Pakistan time on 10 Nov 2026 (02:30 UTC): the 9:00 AM reminder of today is still ahead.
final _morning = DateTime.utc(2026, 11, 10, 2, 30);
// 11:00 AM Pakistan time (06:00 UTC): today's 9:00 AM has passed.
final _late = DateTime.utc(2026, 11, 10, 6);

Parcel parcel(String id, int seq, String? date, {String name = 'Ali Raza', int received = 0, ParcelStatus status = ParcelStatus.sent, CollectionMethod method = CollectionMethod.payLater}) =>
    testParcel(id: id, sequence: seq, customerName: name, method: method, payDate: date, received: received, status: status, customerAddress: 'House 5, Street 2, Sahiwal');

void main() {
  test('a reminder is 09:00 Pakistan time (04:00 UTC) on the parcel\'s date, keyed by its order sequence', () {
    final planned = plannedReminders([parcel('a', 7, '2026-12-25')], _morning);
    expect(planned, hasLength(1));
    expect(planned.single.id, 7);
    expect(planned.single.parcelId, 'a');
    expect(planned.single.instantUtc, DateTime.utc(2026, 12, 25, 4));
  });

  test('today before 9:00 is planned; today after 9:00 is not (the in-app list shows it)', () {
    expect(plannedReminders([parcel('a', 1, '2026-11-10')], _morning).single.instantUtc, DateTime.utc(2026, 11, 10, 4));
    expect(plannedReminders([parcel('a', 1, '2026-11-10')], _late), isEmpty);
  });

  test('nothing for overdue, undated, other types, returned or settled parcels', () {
    final planned = plannedReminders([
      parcel('overdue', 1, '2026-11-01'),
      parcel('nodate', 2, null),
      parcel('collect', 3, '2026-12-01', method: CollectionMethod.postalCollection),
      parcel('returned', 4, '2026-12-01', status: ParcelStatus.returned),
      parcel('paid', 5, '2026-12-01', received: 500000),
      parcel('ok', 6, '2026-12-01'),
    ], _morning);
    expect(planned.map((r) => r.parcelId), ['ok']);
  });

  test('the text names the order, customer and what is left, and never the address', () {
    final r = plannedReminders([parcel('a', 1, '2026-12-25', received: 100000)], _morning).single;
    expect(r.title, 'Payment due: ADT-000001');
    expect(r.body, 'Ali Raza · Rs. 4,000 remaining · due 25 Dec 2026');
    expect('${r.title} ${r.body} ${r.payload}'.contains('Sahiwal'), isFalse);
  });

  test('the payload opens the parcel and changes whenever the notification would change', () {
    final base = plannedReminders([parcel('a', 1, '2026-12-25')], _morning).single;
    expect(parcelIdFromPayload(base.payload), 'a');
    expect(plannedReminders([parcel('a', 1, '2026-12-25')], _morning).single.payload, base.payload, reason: 'unchanged -> same');
    expect(plannedReminders([parcel('a', 1, '2026-12-26')], _morning).single.payload, isNot(base.payload), reason: 'date');
    expect(plannedReminders([parcel('a', 1, '2026-12-25', received: 100000)], _morning).single.payload, isNot(base.payload), reason: 'amount left');
  });
}
