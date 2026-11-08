import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';

void main() {
  group('Pakistan calendar date (fixed UTC+5, no daylight saving)', () {
    test(
      '11:59:59 PM in Pakistan is still the same day; midnight starts the next',
      () {
        expect(
          pakistanDate(DateTime.utc(2026, 11, 8, 18, 59, 59)),
          '2026-11-08',
          reason: '23:59:59 PKT',
        );
        expect(
          pakistanDate(DateTime.utc(2026, 11, 8, 19, 0, 0)),
          '2026-11-09',
          reason: '00:00:00 PKT',
        );
        expect(
          pakistanDate(DateTime.utc(2026, 11, 8, 19, 1)),
          '2026-11-09',
          reason: '00:01 AM PKT',
        );
      },
    );

    test(
      'the UTC day and the Pakistan day differ for five hours every day',
      () {
        expect(
          pakistanDate(DateTime.utc(2026, 11, 8, 0, 0)),
          '2026-11-08',
          reason: '05:00 AM PKT',
        );
        expect(pakistanDate(DateTime.utc(2026, 11, 8, 4, 59)), '2026-11-08');
        expect(
          pakistanDate(DateTime.utc(2026, 11, 8, 23, 59)),
          '2026-11-09',
          reason: 'UTC still the 8th, Pakistan already the 9th',
        );
      },
    );

    test('month, year and leap-day boundaries', () {
      expect(pakistanDate(DateTime.utc(2026, 12, 31, 19)), '2027-01-01');
      expect(pakistanDate(DateTime.utc(2027, 1, 31, 19)), '2027-02-01');
      expect(
        pakistanDate(DateTime.utc(2028, 2, 28, 19)),
        '2028-02-29',
        reason: 'leap day',
      );
      expect(pakistanDate(DateTime.utc(2028, 2, 29, 19)), '2028-03-01');
    });

    test('the same instant gives the same date whether it is given in UTC or as a local time', () {
      final utc = DateTime.utc(2026, 11, 8, 19, 30);
      expect(pakistanDate(utc.toLocal()), pakistanDate(utc));
    });

    test(
      'a payment recorded for noon Pakistan time stays on its day (07:00 UTC)',
      () {
        expect(pakistanDate(DateTime.utc(2026, 11, 7, 7)), '2026-11-07');
      },
    );

    test('formatDate for display', () {
      expect(formatDate('2026-11-09'), '9 Nov 2026');
      expect(formatDate('2028-02-29'), '29 Feb 2028');
    });
  });

  group('reminders follow the same day boundary', () {
    final parcel = testParcel(
      id: 'a',
      method: CollectionMethod.payLater,
      payDate: '2026-11-09',
    );

    test(
      'the reminder instant 04:00 UTC is 9:00 AM in Pakistan on the due date',
      () {
        final planned = plannedReminders([
          parcel,
        ], DateTime.utc(2026, 11, 8, 12));
        expect(planned.single.instantUtc, DateTime.utc(2026, 11, 9, 4));
        expect(pakistanDate(planned.single.instantUtc), '2026-11-09');
      },
    );

    test('11:59 PM the evening before: due tomorrow, still planned; 12:01 AM: due today, still planned until 9:00', () {
      expect(
        plannedReminders([parcel], DateTime.utc(2026, 11, 8, 18, 59)),
        hasLength(1),
      );
      expect(
        plannedReminders([parcel], DateTime.utc(2026, 11, 8, 19, 1)),
        hasLength(1),
        reason: '12:01 AM on the due day, 9:00 is ahead',
      );
      expect(
        plannedReminders([parcel], DateTime.utc(2026, 11, 9, 4, 0, 1)),
        isEmpty,
        reason: 'after 9:00 AM on the day: not a phone notification',
      );
    });
  });
}
