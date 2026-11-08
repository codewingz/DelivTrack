import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/reminders/domain/reminder_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

void main() {
  group('reminderGroupFor', () {
    test('Pay Later with an outstanding balance is grouped by its date', () {
      ReminderGroup? group(String? date) => reminderGroupFor(
        testParcel(method: CollectionMethod.payLater, payDate: date),
        _today,
      );
      expect(group('2026-11-09'), ReminderGroup.overdue);
      expect(group('2000-01-01'), ReminderGroup.overdue);
      expect(
        group('2026-11-10'),
        ReminderGroup.dueToday,
        reason: 'the day itself is due, not overdue',
      );
      expect(group('2026-11-11'), ReminderGroup.upcoming);
      expect(group('2031-01-01'), ReminderGroup.upcoming);
      expect(
        group(null),
        ReminderGroup.noDate,
        reason: 'a parcel without a date is never overdue',
      );
    });

    test('nothing to follow up on other types, returned parcels or settled balances', () {
      expect(
        reminderGroupFor(
          testParcel(
            method: CollectionMethod.postalCollection,
            payDate: '2026-11-01',
          ),
          _today,
        ),
        isNull,
      );
      expect(
        reminderGroupFor(testParcel(method: CollectionMethod.advance), _today),
        isNull,
      );
      expect(
        reminderGroupFor(testParcel(method: CollectionMethod.giftFree), _today),
        isNull,
      );
      expect(
        reminderGroupFor(
          testParcel(
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
            status: ParcelStatus.returned,
          ),
          _today,
        ),
        isNull,
      );
      expect(
        reminderGroupFor(
          testParcel(
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
            received: 500000,
          ),
          _today,
        ),
        isNull,
        reason: 'paid in full',
      );
    });

    test('a partly paid parcel still follows up for what is left', () {
      expect(
        reminderGroupFor(
          testParcel(
            method: CollectionMethod.payLater,
            payDate: '2026-11-01',
            received: 100000,
          ),
          _today,
        ),
        ReminderGroup.overdue,
      );
    });
  });

  group('Reminders', () {
    test('groups are ordered: overdue longest first, upcoming soonest first, no date newest first; bell counts due + overdue', () {
      final parcels = [
        testParcel(
          id: 'u2',
          sequence: 1,
          method: CollectionMethod.payLater,
          payDate: '2026-12-01',
        ),
        testParcel(
          id: 'o2',
          sequence: 2,
          method: CollectionMethod.payLater,
          payDate: '2026-11-05',
        ),
        testParcel(id: 'n1', sequence: 3, method: CollectionMethod.payLater),
        testParcel(
          id: 'd',
          sequence: 4,
          method: CollectionMethod.payLater,
          payDate: _today,
        ),
        testParcel(
          id: 'o1',
          sequence: 5,
          method: CollectionMethod.payLater,
          payDate: '2026-11-01',
        ),
        testParcel(
          id: 'u1',
          sequence: 6,
          method: CollectionMethod.payLater,
          payDate: '2026-11-20',
        ),
        testParcel(id: 'n2', sequence: 7, method: CollectionMethod.payLater),
        testParcel(
          id: 'x',
          sequence: 8,
          method: CollectionMethod.postalCollection,
        ),
      ];
      final r = Reminders.from(parcels, _today);
      expect(r[ReminderGroup.overdue].map((p) => p.id), ['o1', 'o2']);
      expect(r[ReminderGroup.dueToday].map((p) => p.id), ['d']);
      expect(r[ReminderGroup.upcoming].map((p) => p.id), ['u1', 'u2']);
      expect(r[ReminderGroup.noDate].map((p) => p.id), ['n2', 'n1']);
      expect(r.dueCount, 3);
      expect(r.isEmpty, isFalse);
    });

    test('empty when nothing qualifies', () {
      final r = Reminders.from([testParcel()], _today);
      expect(r.isEmpty, isTrue);
      expect(r.dueCount, 0);
    });
  });

  test('daysBetween counts whole days, across month and year ends', () {
    expect(daysBetween('2026-11-09', '2026-11-10'), 1);
    expect(daysBetween('2026-10-31', '2026-11-02'), 2);
    expect(daysBetween('2025-12-31', '2026-01-01'), 1);
    expect(daysBetween('2026-11-10', '2026-11-10'), 0);
  });
}
