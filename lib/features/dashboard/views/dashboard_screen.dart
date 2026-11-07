import 'dart:async';

import 'package:flutter/material.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../../reminders/viewmodel/reminder_list_view_model.dart';

/// Placeholder dashboard: greets the user, shows the reminders bell and offers log out.
/// Parcel and payment totals (FR-11) come with the dashboard feature.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.parcelRepository,
    required this.reminderScheduler,
    required this.onOpenReminders,
    required this.onOpenParcel,
  });
  final AuthRepository repository;
  final ParcelRepository parcelRepository;
  final ReminderScheduler reminderScheduler;
  final VoidCallback onOpenReminders;
  final void Function(String parcelId) onOpenParcel;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final _reminders = ReminderListViewModel(widget.parcelRepository);
  Set<int>? _plannedIds;
  bool _askedForPermission = false;

  @override
  void initState() {
    super.initState();
    _reminders.addListener(_keepPhoneInStep);
    // A notification that started the app opens its parcel once Home is up.
    final launchParcelId = widget.reminderScheduler.takeLaunchParcelId();
    if (launchParcelId != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpenParcel(launchParcelId));
  }

  @override
  void dispose() {
    _reminders.removeListener(_keepPhoneInStep);
    _reminders.dispose();
    super.dispose();
  }

  /// Keeps the phone's scheduled notifications equal to the parcels' Pay Later dates. Also covers a new
  /// phone or a reinstall: the first load after sign-in schedules everything again.
  void _keepPhoneInStep() {
    if (_reminders.isLoading || _reminders.errorMessage != null) return;
    final planned = plannedReminders(_reminders.all, _reminders.clock.nowUtc());
    unawaited(widget.reminderScheduler.sync(planned));
    final ids = {for (final reminder in planned) reminder.id};
    final before = _plannedIds;
    _plannedIds = ids;
    // Ask for permission when a reminder is added while using the app, never at launch.
    if (before != null && ids.difference(before).isNotEmpty) unawaited(_offerNotifications());
  }

  Future<void> _offerNotifications() async {
    if (_askedForPermission || await widget.reminderScheduler.areNotificationsEnabled() || !mounted) return;
    _askedForPermission = true;
    final allow = await showConfirmDialog(
      context,
      title: 'Get payment reminders?',
      message: 'DelivTrack can remind you at 9:00 AM on the day a Pay Later payment is due. Allow notifications to turn this on.',
      confirmLabel: 'Allow',
    );
    if (allow) await widget.reminderScheduler.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DelivTrack'),
        actions: [
          ListenableBuilder(
            listenable: _reminders,
            builder: (context, _) {
              final due = _reminders.reminders.dueCount;
              return IconButton(
                tooltip: due == 0 ? 'Reminders' : 'Reminders, $due due',
                icon: Badge(
                  isLabelVisible: due > 0,
                  label: Text('$due'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: widget.onOpenReminders,
              );
            },
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => confirmLogout(context, repository),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: StreamBuilder<String?>(
                stream: repository.displayNameChanges,
                initialData: repository.displayName,
                builder: (context, snapshot) {
                  final name = snapshot.data?.trim() ?? '';
                  return Text(
                    name.isEmpty ? 'Welcome' : 'Welcome, $name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
