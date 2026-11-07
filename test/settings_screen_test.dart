import 'dart:io';
import 'package:deliv_track/constants/app_info.dart';
import 'package:deliv_track/features/settings/views/settings_screen.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/fake_reminder_scheduler.dart';

Future<void> _open(WidgetTester t, FakeAuthRepository auth, FakeReminderScheduler scheduler, {Size size = const Size(393, 1400), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(MaterialApp(home: SettingsScreen(repository: auth, scheduler: scheduler)));
  await t.pump();
  await t.pump();
}

void main() {
  test('the version shown in Settings is the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });

  testWidgets('shows the account email, the reminder time, the backup note and the version; no inputs', (t) async {
    await _open(t, FakeAuthRepository(signedIn: true, name: 'Ali', accountEmail: 'ali@codewingz.com'), FakeReminderScheduler());
    expect(find.text('ali@codewingz.com'), findsOneWidget);
    expect(find.textContaining('9:00 AM (Pakistan time)'), findsOneWidget);
    expect(find.textContaining('Automatic scheduled backups are not turned on yet'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('notifications on: says On and offers no button', (t) async {
    await _open(t, FakeAuthRepository(signedIn: true), FakeReminderScheduler());
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Turn On Notifications'), findsNothing);
  });

  testWidgets('notifications off: explains, and Turn On asks; when refused it opens the system settings', (t) async {
    final scheduler = FakeReminderScheduler(enabled: false)..allowWhenAsked = false;
    await _open(t, FakeAuthRepository(signedIn: true), scheduler);
    expect(find.textContaining('Off.'), findsOneWidget);
    await t.ensureVisible(find.text('Turn On Notifications'));
    await t.pump();
    await t.tap(find.text('Turn On Notifications'));
    await t.pump();
    await t.pump();
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.settingsOpened, 1);
    expect(find.text('Turn On Notifications'), findsOneWidget, reason: 'still off');
  });

  testWidgets('granting the permission turns the status On', (t) async {
    final scheduler = FakeReminderScheduler(enabled: false);
    await _open(t, FakeAuthRepository(signedIn: true), scheduler);
    await t.ensureVisible(find.text('Turn On Notifications'));
    await t.pump();
    await t.tap(find.text('Turn On Notifications'));
    await t.pump();
    await t.pump();
    expect(find.text('On'), findsOneWidget);
    expect(scheduler.settingsOpened, 0);
  });

  testWidgets('coming back to the app re-reads the permission (changed in the system settings)', (t) async {
    final scheduler = FakeReminderScheduler(enabled: false);
    await _open(t, FakeAuthRepository(signedIn: true), scheduler);
    expect(find.textContaining('Off.'), findsOneWidget);
    scheduler.enabled = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(find.text('On'), findsOneWidget);
  });

  testWidgets('the last scheduling problem is shown only when there is one', (t) async {
    await _open(t, FakeAuthRepository(signedIn: true), FakeReminderScheduler());
    expect(find.text('Last problem scheduling reminders'), findsNothing);
    await _open(t, FakeAuthRepository(signedIn: true), FakeReminderScheduler()..problem = 'Reminders could not be scheduled on this phone.');
    expect(find.text('Last problem scheduling reminders'), findsOneWidget);
    expect(find.text('Reminders could not be scheduled on this phone.'), findsOneWidget);
  });

  testWidgets('Log out asks first and signs out', (t) async {
    final auth = FakeAuthRepository(signedIn: true);
    await _open(t, auth, FakeReminderScheduler());
    await t.ensureVisible(find.text('Log out'));
    await t.pump();
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    expect(auth.signOuts, 0);
    await t.tap(find.widgetWithText(TextButton, 'Log out'));
    await t.pumpAndSettle();
    expect(auth.signOuts, 1);
  });

  testWidgets('More -> Settings opens the screen with the real account email', (t) async {
    t.view.physicalSize = const Size(393, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(DelivTrackApp(
      repository: FakeAuthRepository(signedIn: true, name: 'Ali', accountEmail: 'ali@codewingz.com'),
      productRepository: FakeProductRepository(),
      customerRepository: FakeCustomerRepository(),
      parcelRepository: FakeParcelRepository(),
      reminderScheduler: FakeReminderScheduler(),
    ));
    await t.pump(const Duration(milliseconds: 2000));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('More')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Settings'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('ali@codewingz.com'), findsOneWidget);
  });

  group('responsive', () {
    for (final size in const [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale', (t) async {
          await _open(t, FakeAuthRepository(signedIn: true, accountEmail: 'a.very.long.email.address.for.testing@some-company-name.example.com'), FakeReminderScheduler(enabled: false)..problem = 'Reminders could not be scheduled on this phone. Open the Reminders list to see what is due.', size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.drag(find.byType(ListView), const Offset(0, -3000));
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
