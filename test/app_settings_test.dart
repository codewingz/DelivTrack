import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/dashboard/views/dashboard_screen.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/viewmodel/parcel_form_view_model.dart';
import 'package:deliv_track/features/parcels/views/parcel_details_screen.dart';
import 'package:deliv_track/features/pdf/parcel_document_service.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';
import 'package:deliv_track/features/settings/data/settings_repository.dart';
import 'package:deliv_track/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_reminder_scheduler.dart';

class _FixedClock extends Clock {
  const _FixedClock(this.instant);
  final DateTime instant;
  @override
  DateTime nowUtc() => instant;
}

// 7:30 AM Pakistan time on 10 Nov 2026.
final _morning = DateTime.utc(2026, 11, 10, 2, 30);

void main() {
  group('AppSettings', () {
    test('the defaults: reminders on at 9:00 AM, alerts and prompt on, no parcel defaults', () {
      const settings = AppSettings();
      expect(settings.remindersEnabled, isTrue);
      expect(settings.reminderTimeLabel, '9:00 AM');
      expect(settings.showOverdueAlerts, isTrue);
      expect(settings.promptWhatsAppTracking, isTrue);
      expect(settings.payLaterDueDays, isNull);
      expect(settings.defaultMethod, isNull);
    });

    test('a saved document reads back the same, with or without the optional values', () {
      const full = AppSettings(
        remindersEnabled: false,
        reminderMinutes: 18 * 60 + 5,
        showOverdueAlerts: false,
        payLaterDueDays: 14,
        defaultMethod: CollectionMethod.payLater,
        promptWhatsAppTracking: false,
      );
      expect(AppSettings.fromMap(full.toMap()), full);
      expect(
        AppSettings.fromMap(const AppSettings().toMap()),
        const AppSettings(),
      );
      expect(
        const AppSettings().toMap().containsKey('payLaterDueDays'),
        isFalse,
      );
      expect(const AppSettings().toMap().containsKey('defaultMethod'), isFalse);
    });

    test('a missing or unusable value falls back to its default', () {
      expect(AppSettings.fromMap(const {}), const AppSettings());
      expect(
        AppSettings.fromMap(const {
          'reminderMinutes': 5000,
          'payLaterDueDays': 3,
          'defaultMethod': 'something_new',
          'remindersEnabled': 'yes',
        }),
        const AppSettings(),
      );
    });

    test('copyWith can set the optional values back to none', () {
      const settings = AppSettings(
        payLaterDueDays: 7,
        defaultMethod: CollectionMethod.advance,
      );
      expect(settings.copyWith(reminderMinutes: 60).payLaterDueDays, 7);
      final cleared = settings.copyWith(
        payLaterDueDays: () => null,
        defaultMethod: () => null,
      );
      expect(cleared.payLaterDueDays, isNull);
      expect(cleared.defaultMethod, isNull);
    });

    test('times read as a 12-hour clock', () {
      expect(formatMinutesOfDay(0), '12:00 AM');
      expect(formatMinutesOfDay(9 * 60), '9:00 AM');
      expect(formatMinutesOfDay(12 * 60 + 5), '12:05 PM');
      expect(formatMinutesOfDay(23 * 60 + 59), '11:59 PM');
    });
  });

  group('reminder time', () {
    final parcel = testParcel(
      id: 'a',
      method: CollectionMethod.payLater,
      payDate: '2026-11-10',
    );

    test('a reminder is planned at the chosen Pakistan time', () {
      // 6:30 PM Pakistan time is 13:30 UTC.
      final planned = plannedReminders(
        [parcel],
        _morning,
        minutesOfDay: 18 * 60 + 30,
      );
      expect(planned.single.instantUtc, DateTime.utc(2026, 11, 10, 13, 30));
    });

    test('a time before 5:00 AM falls on the evening before in UTC', () {
      final planned = plannedReminders(
        [
          testParcel(
            id: 'a',
            method: CollectionMethod.payLater,
            payDate: '2026-11-11',
          ),
        ],
        _morning,
        minutesOfDay: 60,
      );
      expect(planned.single.instantUtc, DateTime.utc(2026, 11, 10, 20));
    });

    test('a chosen time that has already passed today is not planned', () {
      expect(
        plannedReminders([parcel], _morning, minutesOfDay: 6 * 60),
        isEmpty,
      );
    });
  });

  group('new parcel defaults', () {
    test('without defaults the form starts empty', () {
      final form = ParcelFormViewModel();
      expect(form.method, isNull);
      expect(form.payDate, isNull);
      expect(form.isDirty, isFalse);
    });

    test(
      'the default parcel type is pre-selected and is not an unsaved change',
      () {
        final form = ParcelFormViewModel(
          defaultMethod: CollectionMethod.postalCollection,
          payLaterDueDays: 14,
          today: '2026-11-10',
        );
        expect(form.method, CollectionMethod.postalCollection);
        expect(form.payDate, isNull, reason: 'only Pay Later has a date');
        expect(form.isDirty, isFalse);
      },
    );

    test(
      'a Pay Later parcel gets today plus the chosen days, across a month end',
      () {
        final form = ParcelFormViewModel(
          defaultMethod: CollectionMethod.payLater,
          payLaterDueDays: 30,
          today: '2026-11-10',
        );
        expect(form.payDate, '2026-12-10');
        expect(form.isDirty, isFalse);
      },
    );

    test('choosing Pay Later later fills the date; leaving it clears it; a typed date is kept', () {
      final form = ParcelFormViewModel(payLaterDueDays: 7, today: '2026-11-10');
      form.setMethod(CollectionMethod.payLater);
      expect(form.payDate, '2026-11-17');
      form.setPayDate('2026-12-01');
      form.setMethod(CollectionMethod.payLater);
      expect(form.payDate, '2026-12-01', reason: 'not overwritten');
      form.setMethod(CollectionMethod.advance);
      expect(form.payDate, isNull);
    });

    test('with no default days the Pay Later date stays empty', () {
      final form = ParcelFormViewModel(today: '2026-11-10');
      form.setMethod(CollectionMethod.payLater);
      expect(form.payDate, isNull);
    });
  });

  group('Home follows the settings', () {
    Future<FakeReminderScheduler> pumpHome(
      WidgetTester t,
      SettingsRepository settings,
    ) async {
      t.view.physicalSize = const Size(393, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final scheduler = FakeReminderScheduler();
      final AuthRepository auth = FakeAuthRepository(
        signedIn: true,
        name: 'Ali',
      );
      await t.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            repository: auth,
            parcelRepository: FakeParcelRepository(
              initial: [
                // due today, and one that is overdue
                testParcel(
                  id: 'a',
                  sequence: 1,
                  method: CollectionMethod.payLater,
                  payDate: '2026-11-10',
                ),
                testParcel(
                  id: 'b',
                  sequence: 2,
                  method: CollectionMethod.payLater,
                  payDate: '2026-11-01',
                ),
              ],
            ),
            reminderScheduler: scheduler,
            settingsRepository: settings,
            onOpenReminders: () {},
            onOpenParcel: (_) {},
            onOpenParcels: (_) {},
            onOpenPayments: () {},
            onAddParcel: () {},
            clock: _FixedClock(_morning),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      await t.pump();
      return scheduler;
    }

    testWidgets(
      'by default the reminder is planned for 9:00 AM and Overdue is listed',
      (t) async {
        final scheduler = await pumpHome(t, MemorySettingsRepository());
        expect(
          scheduler.lastPlanned.single.instantUtc,
          DateTime.utc(2026, 11, 10, 4),
        );
        expect(find.bySemanticsLabel(RegExp('^Overdue: ')), findsOneWidget);
      },
    );

    testWidgets('a change of time re-plans the phone reminders at once', (
      t,
    ) async {
      final settings = MemorySettingsRepository();
      final scheduler = await pumpHome(t, settings);
      await settings.save(const AppSettings(reminderMinutes: 20 * 60));
      await t.pump();
      expect(
        scheduler.lastPlanned.single.instantUtc,
        DateTime.utc(2026, 11, 10, 15),
        reason: '8:00 PM Pakistan time',
      );
    });

    testWidgets(
      'reminders switched off: nothing is planned, so the phone is cleared',
      (t) async {
        final settings = MemorySettingsRepository();
        final scheduler = await pumpHome(t, settings);
        expect(scheduler.lastPlanned, isNotEmpty);
        await settings.save(const AppSettings(remindersEnabled: false));
        await t.pump();
        expect(scheduler.lastPlanned, isEmpty);
      },
    );

    testWidgets(
      'overdue alerts switched off: Overdue leaves Needs attention; due today stays',
      (t) async {
        await pumpHome(
          t,
          MemorySettingsRepository(const AppSettings(showOverdueAlerts: false)),
        );
        expect(find.bySemanticsLabel(RegExp('^Overdue: ')), findsNothing);
        expect(find.textContaining('Reminders due today'), findsOneWidget);
      },
    );
  });

  group('handover follows the settings', () {
    Future<void> handOver(WidgetTester t, SettingsRepository settings) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: ParcelDetailsScreen(
            repository: FakeParcelRepository(
              initial: [
                testParcel(
                  id: 'a',
                  status: ParcelStatus.draft,
                  reference: '',
                  charge: null,
                ),
              ],
            ),
            parcelId: 'a',
            onEdit: (_) async => null,
            documentService: const NoParcelDocumentService(),
            settingsRepository: settings,
          ),
        ),
      );
      await t.pump();
      await t.pump();
      final open = find.widgetWithText(FilledButton, 'Hand over parcel');
      await t.ensureVisible(open);
      await t.pump();
      await t.tap(open);
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Enter tracking number'),
        'PK-999999',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Enter delivery charges'),
        '250',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Hand Over'));
      await t.pumpAndSettle();
    }

    testWidgets('by default it asks to send the tracking update', (t) async {
      await handOver(t, MemorySettingsRepository());
      expect(find.text('Send tracking update?'), findsOneWidget);
    });

    testWidgets(
      'with the prompt switched off it does not ask; the message still offers WhatsApp',
      (t) async {
        await handOver(
          t,
          MemorySettingsRepository(
            const AppSettings(promptWhatsAppTracking: false),
          ),
        );
        expect(find.text('Send tracking update?'), findsNothing);
        expect(find.text('Parcel handed over.'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
      },
    );
  });
}
