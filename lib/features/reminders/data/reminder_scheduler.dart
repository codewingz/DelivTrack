import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../domain/reminder_schedule.dart';

/// Puts the planned reminders on the phone's notification bar.
abstract class ReminderScheduler {
  /// Makes the phone's scheduled notifications exactly [planned]: new ones are scheduled, changed ones
  /// replaced, ones no longer planned removed. Safe to call as often as the parcels change.
  Future<void> sync(List<PlannedReminder> planned);

  /// Removes every scheduled and shown notification (sign-out: nothing may carry over to the next user).
  Future<void> cancelAll();

  Future<bool> areNotificationsEnabled();

  /// Asks Android for the notification permission (Android 13+). Returns whether it is now granted.
  Future<bool> requestPermission();

  /// Opens the system's notification settings for this app.
  Future<void> openSettings();

  /// Parcel ids of notifications the user tapped while the app was running.
  Stream<String> get taps;

  /// The parcel whose notification started the app, once.
  String? takeLaunchParcelId();

  /// A readable problem from the last [sync] (for Settings), or null.
  String? get lastProblem;
}

/// Used where no phone is involved (tests, unsupported platforms).
class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();
  @override
  Future<void> sync(List<PlannedReminder> planned) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<bool> areNotificationsEnabled() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> openSettings() async {}
  @override
  Stream<String> get taps => const Stream.empty();
  @override
  String? takeLaunchParcelId() => null;
  @override
  String? get lastProblem => null;
}

/// Android notifications through flutter_local_notifications. Reminders use inexact timing (they may
/// arrive a few minutes late) so no special "alarms" permission is needed.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  String? _launchParcelId;
  String? _problem;
  Future<void> _queue = Future.value();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pay_later_reminders',
      'Pay Later reminders',
      channelDescription: 'Payments due on Pay Later parcels',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Call once at start-up, before the first [sync].
  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _taps.add(parcelIdFromPayload(payload));
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) _launchParcelId = parcelIdFromPayload(payload);
  }

  @override
  Future<void> sync(List<PlannedReminder> planned) {
    // One run at a time: two overlapping syncs could schedule and cancel against each other.
    return _queue = _queue.then((_) => _sync(planned));
  }

  Future<void> _sync(List<PlannedReminder> planned) async {
    try {
      final pending = {for (final request in await _plugin.pendingNotificationRequests()) request.id: request};
      final wanted = {for (final reminder in planned) reminder.id: reminder};
      for (final id in pending.keys) {
        if (!wanted.containsKey(id)) await _plugin.cancel(id: id);
      }
      for (final reminder in wanted.values) {
        if (pending[reminder.id]?.payload == reminder.payload) continue;
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          payload: reminder.payload,
          scheduledDate: tz.TZDateTime.from(reminder.instantUtc, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      _problem = null;
    } on Object {
      _problem = 'Reminders could not be scheduled on this phone. Open the Reminders list to see what is due.';
    }
  }

  @override
  Future<void> cancelAll() => _queue = _queue.then((_) => _plugin.cancelAll());

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> areNotificationsEnabled() async => await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async => await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> openSettings() async => _android?.openAppNotificationSettings();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  String? takeLaunchParcelId() {
    final id = _launchParcelId;
    _launchParcelId = null;
    return id;
  }

  @override
  String? get lastProblem => _problem;
}
