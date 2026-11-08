import 'package:flutter/material.dart';

import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_info.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';
import '../../reminders/data/reminder_scheduler.dart';

/// Read-only information and the few controls that are not tied to one parcel.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.scheduler,
  });
  final AuthRepository repository;
  final ReminderScheduler scheduler;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _notificationsOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the system settings may have changed the permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await widget.scheduler.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsOn = enabled);
  }

  Future<void> _turnOn() async {
    if (!await widget.scheduler.requestPermission()) {
      await widget.scheduler.openSettings();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.scheduler.lastProblem;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              children: [
                _Section(
                  title: 'Account',
                  children: [
                    _Info('Email', widget.repository.email ?? 'Not available'),
                  ],
                ),
                _Section(
                  title: 'Reminders',
                  children: [
                    _Info(
                      'Reminder time',
                      '9:00 AM (Pakistan time) on the day a Pay Later payment is due',
                    ),
                    _Info('Phone notifications', switch (_notificationsOn) {
                      null => 'Checking...',
                      true => 'On',
                      false => 'Off. Without them the Reminders list inside the app still works.',
                    }),
                    const _Info(
                      'How phone reminders work',
                      'They are set up whenever you open DelivTrack, so open the app after changing a date on another phone. '
                          'They arrive at about 9:00 AM (a few minutes late is normal). A reminder for today that is set after 9:00 AM '
                          'shows in the bell and the Reminders list, not as a phone notification.',
                    ),
                    if (_notificationsOn == false)
                      PrimaryButton(
                        label: 'Turn On Notifications',
                        onPressed: _turnOn,
                      ),
                    if (problem != null)
                      _Info('Last problem scheduling reminders', problem),
                  ],
                ),
                const _Section(
                  title: 'Backup',
                  children: [
                    _Info(
                      'Your data',
                      'Everything is saved to the cloud under your account as you work and is kept private to you. '
                          'Automatic scheduled backups are not turned on yet: they need the Firebase Blaze plan.',
                    ),
                  ],
                ),
                const _Section(
                  title: 'About',
                  children: [_Info('App version', appVersion)],
                ),
                OutlinedButton.icon(
                  onPressed: () => confirmLogout(context, widget.repository),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  label: const Text(
                    'Log out',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              for (final child in children) ...[
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
