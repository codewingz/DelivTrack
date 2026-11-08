import 'dart:async';

import 'package:deliv_track/features/reminders/data/reminder_scheduler.dart';
import 'package:deliv_track/features/reminders/domain/reminder_schedule.dart';

/// Records what the app asks of the phone's notification bar.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.enabled = true, this.launchParcelId});

  bool enabled;
  bool allowWhenAsked = true;
  String? launchParcelId;
  final syncs = <List<PlannedReminder>>[];
  int cancelAlls = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;
  final tapController = StreamController<String>.broadcast();

  List<PlannedReminder> get lastPlanned => syncs.last;

  @override
  Future<void> sync(List<PlannedReminder> planned) async => syncs.add(planned);

  @override
  Future<void> cancelAll() async => cancelAlls++;

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (allowWhenAsked) enabled = true;
    return enabled;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<String> get taps => tapController.stream;

  @override
  String? takeLaunchParcelId() {
    final id = launchParcelId;
    launchParcelId = null;
    return id;
  }

  String? problem;

  @override
  String? get lastProblem => problem;
}
