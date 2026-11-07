import 'package:flutter/material.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/views/parcel_action_sheets.dart';
import '../../parcels/views/payment_sheet.dart';
import '../domain/reminder_rules.dart';
import '../viewmodel/reminder_list_view_model.dart';

/// Pay Later follow-ups: due today, overdue, upcoming and without a date. Works without notification
/// permission: this list is always available inside the app.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.repository, required this.onOpen, this.clock = const Clock()});
  final ParcelRepository repository;
  final void Function(Parcel parcel) onOpen;
  final Clock clock;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final _viewModel = ReminderListViewModel(widget.repository, clock: widget.clock);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() open, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await open()) messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(listenable: _viewModel, builder: (context, _) => _body(context)),
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
    if (_viewModel.isLoading) return const SingleChildScrollView(child: ListSkeleton());
    final reminders = _viewModel.reminders;
    if (reminders.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing to follow up',
        message: 'Pay Later parcels that still owe money appear here.',
      );
    }
    final today = _viewModel.today;
    return CustomScrollView(
      slivers: [
        for (final group in ReminderGroup.values)
          if (reminders[group].isNotEmpty) ...[
            SliverToBoxAdapter(child: _GroupHeader(group: group, count: reminders[group].length)),
            SliverList.builder(
              itemCount: reminders[group].length,
              itemBuilder: (context, index) {
                final parcel = reminders[group][index];
                return _ReminderTile(
                  parcel: parcel,
                  group: group,
                  today: today,
                  onOpen: () => widget.onOpen(parcel),
                  onReceive: () => _act(() => showPaymentSheet(context, widget.repository, parcel), 'Payment recorded.'),
                  onChangeDate: () => _act(() => showPayLaterDateSheet(context, widget.repository, parcel, clock: widget.clock), 'Pay Later date saved.'),
                );
              },
            ),
          ],
        const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl)),
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
    final urgent = group == ReminderGroup.overdue || group == ReminderGroup.dueToday;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          '${group.label} ($count)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: urgent ? AppColors.error : AppColors.primaryDark),
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

  String get _dateText {
    final date = parcel.estimatedPaymentDate;
    return switch (group) {
      ReminderGroup.noDate => 'No date set',
      ReminderGroup.dueToday => 'Due today',
      ReminderGroup.overdue => () {
          final days = daysBetween(date!, today);
          return 'Overdue by $days ${days == 1 ? 'day' : 'days'} · ${formatDate(date)}';
        }(),
      ReminderGroup.upcoming => 'Due ${formatDate(date!)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel.orderNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const SizedBox(height: AppSpacing.xs),
                Text(parcel.customerName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  'Outstanding ${formatRupees(parcel.outstandingPaisa)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(_dateText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: group == ReminderGroup.overdue ? AppColors.error : AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
          child: Wrap(
            children: [
              TextButton(onPressed: onReceive, child: const Text('Mark Received')),
              TextButton(onPressed: onChangeDate, child: Text(group == ReminderGroup.noDate ? 'Set Date' : 'Change Date')),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
