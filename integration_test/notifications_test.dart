// Real Android notifications on the emulator (no Firebase needed).
// The app needs the notification permission already granted, so install it first with -g:
//   flutter build apk --debug --target integration_test/notifications_test.dart
//   adb install -g -r build/app/outputs/flutter-apk/app-debug.apk
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/notifications_test.dart -d <emulator> --use-application-binary build/app/outputs/flutter-apk/app-debug.apk
import 'package:deliv_track/features/reminders/data/reminder_scheduler.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a scheduled reminder is held by the phone, replaced without duplicates, shown at its time and cleared', (t) async {
    final scheduler = LocalNotificationScheduler();
    await scheduler.init();
    expect(await scheduler.areNotificationsEnabled(), isTrue, reason: 'install the app with adb install -g');
    await scheduler.cancelAll();

    final plugin = FlutterLocalNotificationsPlugin();
    Future<List<PendingNotificationRequest>> pending() => plugin.pendingNotificationRequests();
    PlannedReminder reminder(int id, DateTime at, {String body = 'Ali Raza · Rs. 5,000 remaining'}) =>
        PlannedReminder(id: id, parcelId: 'parcel$id', instantUtc: at, title: 'Payment due: ADT-$id', body: body);

    // --- scheduled for tomorrow: pending, not shown
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    await scheduler.sync([reminder(41, tomorrow), reminder(42, tomorrow)]);
    expect((await pending()).map((p) => p.id).toSet(), {41, 42});
    expect(scheduler.lastProblem, isNull);

    // --- syncing again does not duplicate; a changed one is replaced; a removed one is cancelled
    await scheduler.sync([reminder(41, tomorrow, body: 'Ali Raza · Rs. 3,000 remaining')]);
    final held = await pending();
    expect(held.map((p) => p.id), [41]);
    expect(held.single.body, contains('Rs. 3,000'));

    // --- one that is due in a few seconds is really shown
    await scheduler.sync([reminder(41, tomorrow), reminder(43, DateTime.now().toUtc().add(const Duration(seconds: 6)))]);
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    var shown = <ActiveNotification>[];
    for (var i = 0; i < 90 && shown.isEmpty; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      shown = (await android.getActiveNotifications()).where((n) => n.id == 43).toList();
    }
    expect(shown, isNotEmpty, reason: 'the reminder reached the notification bar');
    expect(shown.single.title, 'Payment due: ADT-43');
    expect(shown.single.body, contains('Ali Raza'));

    // --- sign-out clears everything
    await scheduler.cancelAll();
    expect(await pending(), isEmpty);
    expect(await android.getActiveNotifications(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
