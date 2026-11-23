import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_dropdown_field.dart';
import '../../../common_widgets/app_snack_bar.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/powered_by_pill.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

/// The owner's preferences: reminders, defaults for new parcels and the
/// account. Every change is saved straight away.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.scheduler,
    this.settingsRepository = const NoSettingsRepository(),
  });
  final AuthRepository repository;
  final ReminderScheduler scheduler;
  final SettingsRepository settingsRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _notificationsOn;
  late AppSettings _settings = widget.settingsRepository.current;
  StreamSubscription<AppSettings>? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = widget.settingsRepository.watch().listen((settings) {
      if (mounted) setState(() => _settings = settings);
      // A failure to load keeps the settings already shown.
    }, onError: (Object _) {});
    _refresh();
  }

  @override
  void dispose() {
    _changes?.cancel();
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

  /// Shows the change at once and saves it; a failed save puts the old value
  /// back and says why.
  Future<void> _save(AppSettings next) async {
    final before = _settings;
    if (next == before) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _settings = next);
    try {
      await widget.settingsRepository.save(next);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _settings = before);
      messenger.showSnackBar(appSnackBar(e.message));
    }
  }

  Future<void> _pickReminderTime() async {
    final minutes = _settings.reminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Reminder time (Pakistan time)',
    );
    if (picked == null) return;
    await _save(
      _settings.copyWith(reminderMinutes: picked.hour * 60 + picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.scheduler.lastProblem;
    final settings = _settings;
    return Scaffold(
      // The backdrop continues behind the header's curve.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: const AppBarTitle(
          'Settings',
          subtitle: 'Notifications & defaults',
        ),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('Notifications', first: true),
                    _Group(
                      children: [
                        _SwitchRow(
                          title: 'Payment reminders',
                          subtitle: 'Phone notification on the day a Pay Later payment is due',
                          value: settings.remindersEnabled,
                          onChanged: (on) =>
                              _save(settings.copyWith(remindersEnabled: on)),
                        ),
                        ListTile(
                          minTileHeight: 64,
                          contentPadding: _rowPadding,
                          enabled: settings.remindersEnabled,
                          title: const Text('Reminder time', style: _rowTitle),
                          subtitle: const Text(
                            'Pakistan time, on the due day',
                            style: _rowSubtitle,
                          ),
                          trailing: Text(
                            settings.reminderTimeLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: settings.remindersEnabled
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          onTap: _pickReminderTime,
                        ),
                        _SwitchRow(
                          title: 'Overdue Pay Later alerts',
                          subtitle: 'Show overdue items in Needs attention',
                          value: settings.showOverdueAlerts,
                          onChanged: (on) =>
                              _save(settings.copyWith(showOverdueAlerts: on)),
                        ),
                      ],
                    ),
                    // Android can block notifications whatever is chosen
                    // above; this is the way to allow them.
                    if (settings.remindersEnabled && _notificationsOn == false)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _Group(
                          padded: true,
                          children: [
                            const Text(
                              'Phone notifications are off',
                              style: _rowTitle,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Android is not allowing DelivTrack to show notifications. The Reminders list inside the app still works.',
                              style: _rowSubtitle,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            PrimaryButton(
                              label: 'Turn On Notifications',
                              onPressed: _turnOn,
                            ),
                          ],
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xs,
                        AppSpacing.sm,
                        AppSpacing.xs,
                        0,
                      ),
                      child: Text(
                        'Reminders are set up whenever you open DelivTrack, so open the app after changing a date on another phone. A few minutes late is normal.',
                        style: TextStyle(fontSize: 12, color: AppColors.label),
                      ),
                    ),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.xs,
                          AppSpacing.sm,
                          AppSpacing.xs,
                          0,
                        ),
                        child: Text(
                          problem,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const _SectionLabel('Dispatch & defaults'),
                    _Group(
                      padded: true,
                      children: [
                        // An empty value stands for "Ask every time".
                        AppDropdownField<String>(
                          label: 'Default parcel type',
                          hint: 'Ask every time',
                          value: settings.defaultMethod?.value ?? '',
                          options: [
                            (value: '', label: 'Ask every time'),
                            for (final method in CollectionMethod.values)
                              (value: method.value, label: method.label),
                          ],
                          onChanged: (value) => _save(
                            settings.copyWith(
                              defaultMethod: () => CollectionMethod.values
                                  .where((method) => method.value == value)
                                  .firstOrNull,
                            ),
                          ),
                        ),
                        const Divider(
                          height: AppSpacing.x3l,
                          color: AppColors.border,
                        ),
                        _SwitchRow(
                          dense: true,
                          title: 'Auto-prompt WhatsApp tracking',
                          subtitle: 'Ask to send tracking right after handover',
                          value: settings.promptWhatsAppTracking,
                          onChanged: (on) => _save(
                            settings.copyWith(promptWhatsAppTracking: on),
                          ),
                        ),
                      ],
                    ),
                    const _SectionLabel('Account'),
                    _Group(
                      padded: true,
                      children: [
                        _Info(
                          'Email',
                          widget.repository.email ?? 'Not available',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Align(child: PoweredByPill()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _rowPadding = EdgeInsetsDirectional.fromSTEB(
  AppSpacing.lg,
  AppSpacing.xs,
  AppSpacing.md,
  AppSpacing.xs,
);
const _rowTitle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const _rowSubtitle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

/// Small uppercase heading above a group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.first = false});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        first ? 0 : AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.label,
          ),
        ),
      ),
    );
  }
}

/// A glass card of rows (separated by thin lines), or of free content when
/// [padded].
class _Group extends StatelessWidget {
  const _Group({required this.children, this.padded = false});
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return App3DCard(
      glass: true,
      padding: padded ? const EdgeInsets.all(AppSpacing.lg) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (!padded && index > 0)
              const Divider(height: 1, color: AppColors.border),
            child,
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Inside a padded group, where the row needs no padding of its own.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: dense ? EdgeInsets.zero : _rowPadding,
      activeTrackColor: AppColors.primary,
      title: Text(title, style: _rowTitle),
      subtitle: Text(subtitle, style: _rowSubtitle),
      value: value,
      onChanged: onChanged,
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
        Text(label, style: _rowSubtitle),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
