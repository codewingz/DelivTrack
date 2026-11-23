import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/settings/data/settings_repository.dart';
import 'package:deliv_track/features/settings/domain/app_settings.dart';
import 'package:deliv_track/features/settings/views/settings_screen.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/dropdown_finders.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/fake_reminder_scheduler.dart';
import 'helpers/tab_finders.dart';

Future<MemorySettingsRepository> _open(
  WidgetTester t,
  FakeAuthRepository auth,
  FakeReminderScheduler scheduler, {
  Size size = const Size(393, 1600),
  double scale = 1,
  MemorySettingsRepository? settings,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final repo = settings ?? MemorySettingsRepository();
  await t.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        repository: auth,
        scheduler: scheduler,
        settingsRepository: repo,
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return repo;
}

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

void main() {
  testWidgets(
    'shows the defaults and the account email; no app version, backup note or Log out',
    (t) async {
      await _open(
        t,
        FakeAuthRepository(
          signedIn: true,
          name: 'Ali',
          accountEmail: 'ali@codewingz.com',
        ),
        FakeReminderScheduler(),
      );
      expect(
        t.widget<SwitchListTile>(_switch('Payment reminders')).value,
        true,
      );
      expect(
        t.widget<SwitchListTile>(_switch('Overdue Pay Later alerts')).value,
        true,
      );
      expect(
        t
            .widget<SwitchListTile>(_switch('Auto-prompt WhatsApp tracking'))
            .value,
        true,
      );
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('No default date'), findsOneWidget);
      expect(find.text('Ask every time'), findsOneWidget);
      expect(find.text('ali@codewingz.com'), findsOneWidget);
      expect(find.text('App version'), findsNothing);
      expect(
        find.textContaining('whenever you open DelivTrack'),
        findsOneWidget,
      );
      expect(find.textContaining('backup'), findsNothing);
      expect(find.text('Log out'), findsNothing);
      expect(
        find.text('Powered by  CodeWingz', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('each switch saves its change straight away', (t) async {
    final repo = await _open(
      t,
      FakeAuthRepository(signedIn: true),
      FakeReminderScheduler(),
    );
    await t.tap(_switch('Payment reminders'));
    await t.pump();
    expect(repo.current.remindersEnabled, isFalse);
    await t.tap(_switch('Overdue Pay Later alerts'));
    await t.pump();
    expect(repo.current.showOverdueAlerts, isFalse);
    await t.ensureVisible(_switch('Auto-prompt WhatsApp tracking'));
    await t.pump();
    await t.tap(_switch('Auto-prompt WhatsApp tracking'));
    await t.pump();
    expect(repo.current.promptWhatsAppTracking, isFalse);
    // the others are untouched
    expect(repo.current.reminderMinutes, AppSettings.defaultReminderMinutes);
    expect(repo.current.payLaterDueDays, isNull);
    expect(repo.current.defaultMethod, isNull);
  });

  testWidgets(
    'the dropdowns save the Pay Later due days and the default parcel type, and can be cleared',
    (t) async {
      final repo = await _open(
        t,
        FakeAuthRepository(signedIn: true),
        FakeReminderScheduler(),
      );
      await chooseOption(t, 'Pay Later due', '14 days');
      expect(repo.current.payLaterDueDays, 14);
      await chooseOption(t, 'Default parcel type', 'Pay Later');
      expect(repo.current.defaultMethod, CollectionMethod.payLater);
      await chooseOption(t, 'Pay Later due', 'No default date');
      expect(repo.current.payLaterDueDays, isNull);
      await chooseOption(t, 'Default parcel type', 'Ask every time');
      expect(repo.current.defaultMethod, isNull);
    },
  );

  testWidgets('the reminder time is picked with the time picker and saved', (
    t,
  ) async {
    final repo = await _open(
      t,
      FakeAuthRepository(signedIn: true),
      FakeReminderScheduler(),
      settings: MemorySettingsRepository(
        const AppSettings(reminderMinutes: 18 * 60 + 30),
      ),
    );
    expect(find.text('6:30 PM'), findsOneWidget);
    await t.tap(find.text('Reminder time'));
    await t.pumpAndSettle();
    expect(find.text('Reminder time (Pakistan time)'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(repo.current.reminderMinutes, 18 * 60 + 30, reason: 'unchanged');
  });

  testWidgets('a save that fails puts the old value back and says why', (
    t,
  ) async {
    final repo = MemorySettingsRepository()
      ..failure = const AppFailure('No internet connection.');
    await _open(
      t,
      FakeAuthRepository(signedIn: true),
      FakeReminderScheduler(),
      settings: repo,
    );
    await t.tap(_switch('Payment reminders'));
    await t.pumpAndSettle();
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(t.widget<SwitchListTile>(_switch('Payment reminders')).value, true);
    expect(repo.current.remindersEnabled, isTrue);
  });

  testWidgets('a change made on another phone shows up', (t) async {
    final repo = await _open(
      t,
      FakeAuthRepository(signedIn: true),
      FakeReminderScheduler(),
    );
    await repo.save(const AppSettings(reminderMinutes: 7 * 60));
    await t.pump();
    expect(find.text('7:00 AM'), findsOneWidget);
  });

  testWidgets('notifications allowed by Android: no Turn On button', (t) async {
    await _open(t, FakeAuthRepository(signedIn: true), FakeReminderScheduler());
    expect(find.text('Turn On Notifications'), findsNothing);
  });

  testWidgets(
    'notifications blocked by Android: explains, and Turn On asks; when refused it opens the system settings',
    (t) async {
      final scheduler = FakeReminderScheduler(enabled: false)
        ..allowWhenAsked = false;
      await _open(t, FakeAuthRepository(signedIn: true), scheduler);
      expect(find.text('Phone notifications are off'), findsOneWidget);
      await t.ensureVisible(find.text('Turn On Notifications'));
      await t.pump();
      await t.tap(find.text('Turn On Notifications'));
      await t.pump();
      await t.pump();
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.settingsOpened, 1);
      expect(
        find.text('Turn On Notifications'),
        findsOneWidget,
        reason: 'still off',
      );
    },
  );

  testWidgets('granting the permission removes the Turn On button', (t) async {
    final scheduler = FakeReminderScheduler(enabled: false);
    await _open(t, FakeAuthRepository(signedIn: true), scheduler);
    await t.ensureVisible(find.text('Turn On Notifications'));
    await t.pump();
    await t.tap(find.text('Turn On Notifications'));
    await t.pump();
    await t.pump();
    expect(find.text('Turn On Notifications'), findsNothing);
    expect(scheduler.settingsOpened, 0);
  });

  testWidgets(
    'reminders switched off in Settings: the Android notice is not shown',
    (t) async {
      await _open(
        t,
        FakeAuthRepository(signedIn: true),
        FakeReminderScheduler(enabled: false),
        settings: MemorySettingsRepository(
          const AppSettings(remindersEnabled: false),
        ),
      );
      expect(find.text('Turn On Notifications'), findsNothing);
    },
  );

  testWidgets(
    'coming back to the app re-reads the permission (changed in the system settings)',
    (t) async {
      final scheduler = FakeReminderScheduler(enabled: false);
      await _open(t, FakeAuthRepository(signedIn: true), scheduler);
      expect(find.text('Turn On Notifications'), findsOneWidget);
      scheduler.enabled = true;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump();
      expect(find.text('Turn On Notifications'), findsNothing);
    },
  );

  testWidgets('the last scheduling problem is shown only when there is one', (
    t,
  ) async {
    const problem = 'Reminders could not be scheduled on this phone.';
    await _open(t, FakeAuthRepository(signedIn: true), FakeReminderScheduler());
    expect(find.text(problem), findsNothing);
    await _open(
      t,
      FakeAuthRepository(signedIn: true),
      FakeReminderScheduler()..problem = problem,
    );
    expect(find.text(problem), findsOneWidget);
  });

  testWidgets('More -> Settings opens the screen with the real account email', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      DelivTrackApp(
        repository: FakeAuthRepository(
          signedIn: true,
          name: 'Ali',
          accountEmail: 'ali@codewingz.com',
        ),
        productRepository: FakeProductRepository(),
        customerRepository: FakeCustomerRepository(),
        parcelRepository: FakeParcelRepository(),
        reminderScheduler: FakeReminderScheduler(),
      ),
    );
    await t.pump(const Duration(milliseconds: 2000));
    await t.pumpAndSettle();
    await t.tap(tabButton('More'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Settings'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('ali@codewingz.com'), findsOneWidget);
  });

  group('responsive', () {
    for (final size in const [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(640, 300),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await _open(
            t,
            FakeAuthRepository(
              signedIn: true,
              accountEmail: 'a.very.long.email.address.for.testing@some-company-name.example.com',
            ),
            FakeReminderScheduler(enabled: false)..problem = 'Reminders could not be scheduled on this phone. Open the Reminders list to see what is due.',
            size: size,
            scale: scale,
          );
          expect(t.takeException(), isNull);
          await t.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -3000),
          );
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
