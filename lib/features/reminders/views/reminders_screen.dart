import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_snack_bar.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/domain/parcel_enums.dart';
import '../../parcels/views/parcel_action_sheets.dart';
import '../../parcels/views/payment_sheet.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder_rules.dart';
import '../viewmodel/reminder_list_view_model.dart';

/// Pay Later follow-ups: due today, overdue, upcoming and without a date. Works without notification
/// permission: this list is always available inside the app.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.repository,
    required this.onOpen,
    this.scheduler = const NoReminderScheduler(),
    this.clock = const Clock(),
  });
  final ParcelRepository repository;
  final ReminderScheduler scheduler;
  final void Function(Parcel parcel) onOpen;
  final Clock clock;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final _viewModel = ReminderListViewModel(
    widget.repository,
    clock: widget.clock,
  );

  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _refreshNotificationState();
  }

  Future<void> _refreshNotificationState() async {
    final enabled = await widget.scheduler.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsOn = enabled);
  }

  Future<void> _turnOnNotifications() async {
    if (!await widget.scheduler.requestPermission()) {
      await widget.scheduler.openSettings();
    }
    await _refreshNotificationState();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() open, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await open()) messenger.showSnackBar(appSnackBar(done));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The backdrop continues behind the header's curve.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: const AppBarTitle(
          'Reminders',
          subtitle: 'Pay Later follow-ups',
          icon: Icons.notifications_none_rounded,
        ),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _body(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_viewModel.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load reminders",
        message: _viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: _viewModel.retry,
      );
    }
    if (_viewModel.isLoading) {
      return const SingleChildScrollView(child: ListSkeleton());
    }
    final reminders = _viewModel.reminders;
    if (reminders.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing to follow up',
        message: 'Pay Later parcels that still owe money appear here.',
      );
    }
    final today = _viewModel.today;
    final hasDated =
        reminders[ReminderGroup.dueToday].isNotEmpty ||
        reminders[ReminderGroup.upcoming].isNotEmpty;
    return CustomScrollView(
      slivers: [
        if (!_notificationsOn && hasDated)
          SliverToBoxAdapter(
            child: _NotificationsOffBanner(onTurnOn: _turnOnNotifications),
          ),
        for (final group in ReminderGroup.values)
          if (reminders[group].isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _GroupHeader(group: group, count: reminders[group].length),
            ),
            SliverList.builder(
              itemCount: reminders[group].length,
              itemBuilder: (context, index) {
                final parcel = reminders[group][index];
                return _ReminderTile(
                  parcel: parcel,
                  group: group,
                  today: today,
                  onOpen: () => widget.onOpen(parcel),
                  onReceive: () => _act(
                    () => showPaymentSheet(context, widget.repository, parcel),
                    'Payment recorded.',
                  ),
                  onChangeDate: () => _act(
                    () => showPayLaterDateSheet(
                      context,
                      widget.repository,
                      parcel,
                      clock: widget.clock,
                    ),
                    'Pay Later date saved.',
                  ),
                );
              },
            ),
          ],
        const SliverPadding(
          padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});
  final ReminderGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final urgent =
        group == ReminderGroup.overdue || group == ReminderGroup.dueToday;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          '${group.label} ($count)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: urgent ? AppColors.error : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.parcel,
    required this.group,
    required this.today,
    required this.onOpen,
    required this.onReceive,
    required this.onChangeDate,
  });
  final Parcel parcel;
  final ReminderGroup group;
  final String today;
  final VoidCallback onOpen;
  final VoidCallback onReceive;
  final VoidCallback onChangeDate;

  @override
  Widget build(BuildContext context) {
    final urgent =
        group == ReminderGroup.overdue || group == ReminderGroup.dueToday;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: App3DCard(
        glass: true,
        onTap: onOpen,
        stripeColor: urgent ? AppColors.error : AppColors.primary,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The order number, with the amount at the end; the amount moves
            // below when large text leaves no room.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              children: [
                Text(
                  parcel.orderNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: Text(
                    'Outstanding ${formatRupees(parcel.outstandingPaisa)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pending,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              parcel.customerName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              reminderDateText(parcel, group, today),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: group == ReminderGroup.overdue
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
            const Divider(height: AppSpacing.xl, color: AppColors.border),
            Wrap(
              children: [
                // Not for a draft: money is recorded only after the handover.
                if (parcel.status == ParcelStatus.sent)
                  TextButton.icon(
                    onPressed: onReceive,
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    label: const Text('Mark Received'),
                  ),
                TextButton.icon(
                  onPressed: onChangeDate,
                  icon: const Icon(Icons.event_outlined, size: 20),
                  label: Text(
                    group == ReminderGroup.noDate ? 'Set Date' : 'Change Date',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsOffBanner extends StatelessWidget {
  const _NotificationsOffBanner({required this.onTurnOn});
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        top: AppSpacing.lg,
        end: AppSpacing.lg,
      ),
      child: App3DCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Phone notifications are off',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Turn them on to get a reminder on the day a payment is due, at the time set in Settings. This list always works without them.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: 'Turn On Notifications', onPressed: onTurnOn),
          ],
        ),
      ),
    );
  }
}
