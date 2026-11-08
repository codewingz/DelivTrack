import 'package:deliv_track/features/reminders/data/reminder_scheduler.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedReminder _r(
  int id, {
  int day = 25,
  String body = 'Ali Raza · Rs. 5,000 remaining',
}) => PlannedReminder(
  id: id,
  parcelId: 'p$id',
  instantUtc: DateTime.utc(2030, 12, day, 4),
  title: 'Payment due: ADT-$id',
  body: body,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late List<Map<String, Object?>> pending;
  Object? failWith;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    pending = [];
    failWith = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (failWith != null && call.method == 'zonedSchedule') {
            throw failWith!;
          }
          switch (call.method) {
            case 'pendingNotificationRequests':
              return pending;
            case 'areNotificationsEnabled':
              return false;
            case 'requestNotificationsPermission':
              return true;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  List<MethodCall> of(String method) =>
      calls.where((c) => c.method == method).toList();

  testWidgets(
    'new reminders are scheduled at their instant with inexact timing',
    (t) async {
      final scheduler = LocalNotificationScheduler();
      await scheduler.sync([_r(1), _r(2, day: 26)]);
      final scheduled = of('zonedSchedule');
      expect(scheduled.map((c) => (c.arguments as Map)['id']), [1, 2]);
      expect((scheduled.first.arguments as Map)['title'], 'Payment due: ADT-1');
      expect(
        (scheduled.first.arguments as Map)['scheduleMode'],
        isNot('exact'),
        reason: 'no exact-alarm permission is used',
      );
      expect(scheduler.lastProblem, isNull);
    },
  );

  testWidgets(
    'unchanged reminders are left alone, changed ones replaced, removed ones cancelled',
    (t) async {
      final scheduler = LocalNotificationScheduler();
      final same = _r(1);
      pending = [
        {
          'id': 1,
          'title': same.title,
          'body': same.body,
          'payload': same.payload,
        },
        {'id': 2, 'title': 'old', 'body': 'old', 'payload': 'old'},
        {'id': 3, 'title': 'gone', 'body': 'gone', 'payload': 'gone'},
      ];
      await scheduler.sync([same, _r(2, day: 27)]);
      expect(of('zonedSchedule').map((c) => (c.arguments as Map)['id']), [
        2,
      ], reason: 'only the changed one is scheduled again');
      expect(of('cancel').map((c) => (c.arguments as Map)['id']), [
        3,
      ], reason: 'the one no longer planned is cancelled');
    },
  );

  testWidgets(
    'a scheduling error is kept as a readable problem and a later sync clears it',
    (t) async {
      final scheduler = LocalNotificationScheduler();
      failWith = PlatformException(code: 'exact_alarms_not_permitted');
      await scheduler.sync([_r(1)]);
      expect(scheduler.lastProblem, isNotNull);
      failWith = null;
      await scheduler.sync([_r(1)]);
      expect(scheduler.lastProblem, isNull);
    },
  );

  testWidgets('overlapping syncs run one after the other', (t) async {
    final scheduler = LocalNotificationScheduler();
    await Future.wait([
      scheduler.sync([_r(1)]),
      scheduler.sync([]),
      scheduler.sync([_r(2)]),
    ]);
    final order = [
      for (final c in calls)
        if (c.method == 'zonedSchedule') (c.arguments as Map)['id'],
    ];
    expect(order, [1, 2]);
  });

  testWidgets(
    'a failure while setting the plugin up never throws; it is kept as a readable problem',
    (t) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') {
              throw PlatformException(code: 'boom');
            }
            return null;
          });
      final scheduler = LocalNotificationScheduler();
      await scheduler.init();
      expect(scheduler.lastProblem, contains('could not be set up'));
    },
  );

  testWidgets('reminders are private on a locked screen', (t) async {
    final scheduler = LocalNotificationScheduler();
    await scheduler.sync([_r(1)]);
    final platformSpecifics =
        (of('zonedSchedule').single.arguments as Map)['platformSpecifics']
            as Map;
    // NotificationVisibility.private has the integer value 0 on Android.
    expect(platformSpecifics['visibility'], 0);
  });

  testWidgets('cancelAll clears the phone; permission calls go through', (
    t,
  ) async {
    final scheduler = LocalNotificationScheduler();
    await scheduler.cancelAll();
    expect(of('cancelAll'), hasLength(1));
    expect(await scheduler.areNotificationsEnabled(), isFalse);
    expect(await scheduler.requestPermission(), isTrue);
  });
}
