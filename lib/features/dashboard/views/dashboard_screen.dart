import 'dart:async';

import 'package:flutter/material.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/count_badge.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel_search.dart';
import '../../parcels/views/parcels_screen.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../../reminders/viewmodel/reminder_list_view_model.dart';
import '../domain/dashboard_stats.dart';

/// Home: greeting, quick actions, the figures that matter (each count opens the list behind it),
/// and the newest parcels. It also keeps the phone's reminders in step with the parcels.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.parcelRepository,
    required this.reminderScheduler,
    required this.onOpenReminders,
    required this.onOpenParcel,
    required this.onOpenParcels,
    required this.onOpenPayments,
    required this.onAddParcel,
  });
  final AuthRepository repository;
  final ParcelRepository parcelRepository;
  final ReminderScheduler reminderScheduler;
  final VoidCallback onOpenReminders;
  final void Function(String parcelId) onOpenParcel;

  /// Opens the Parcels list narrowed by these filters.
  final void Function(ParcelFilters filters) onOpenParcels;
  final VoidCallback onOpenPayments;
  final VoidCallback onAddParcel;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Every parcel, live. The figures, the bell and the phone's reminders all come from this one list.
  late final _parcels = ReminderListViewModel(widget.parcelRepository, includeArchived: true);
  Set<int>? _plannedIds;
  bool _askedForPermission = false;

  @override
  void initState() {
    super.initState();
    _parcels.addListener(_keepPhoneInStep);
    // A notification that started the app opens its parcel once Home is up.
    final launchParcelId = widget.reminderScheduler.takeLaunchParcelId();
    if (launchParcelId != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpenParcel(launchParcelId));
  }

  @override
  void dispose() {
    _parcels.removeListener(_keepPhoneInStep);
    _parcels.dispose();
    super.dispose();
  }

  /// Keeps the phone's scheduled notifications equal to the parcels' Pay Later dates. Also covers a new
  /// phone or a reinstall: the first load after sign-in schedules everything again.
  void _keepPhoneInStep() {
    if (_parcels.isLoading || _parcels.errorMessage != null) return;
    final planned = plannedReminders(_parcels.all, _parcels.clock.nowUtc());
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
            listenable: _parcels,
            builder: (context, _) {
              final due = _parcels.reminders.dueCount;
              return IconButton(
                tooltip: due == 0 ? 'Reminders' : 'Reminders, $due due',
                icon: CountBadge(count: due, child: const Icon(Icons.notifications_none_rounded)),
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListenableBuilder(listenable: _parcels, builder: (context, _) => _body()),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_parcels.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load your figures",
        message: _parcels.errorMessage,
        actionLabel: 'Retry',
        onAction: _parcels.retry,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _parcels.retry(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<String?>(
              stream: widget.repository.displayNameChanges,
              initialData: widget.repository.displayName,
              builder: (context, snapshot) {
                final name = snapshot.data?.trim() ?? '';
                return Text(
                  name.isEmpty ? 'Welcome' : 'Welcome, $name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                );
              },
            ),
            _UnreadableNotice(repository: widget.parcelRepository),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                FilledButton.icon(onPressed: widget.onAddParcel, icon: const Icon(Icons.add), label: const Text('Add Parcel')),
                OutlinedButton.icon(onPressed: () => widget.onOpenParcels(ParcelFilters.none), icon: const Icon(Icons.search_rounded), label: const Text('Search')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_parcels.isLoading)
              const ListSkeleton()
            else ...[
              _Figures(stats: DashboardStats.from(_parcels.all, _parcels.today), widget: widget),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Parcel counts and balances cover active parcels. Total received and Advance amount also include archived parcels.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Recent(stats: DashboardStats.from(_parcels.all, _parcels.today), widget: widget),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when stored parcels can't be read: they are left out of every list and total, and this says so
/// (with their ids only, never customer data) so they can be repaired.
class _UnreadableNotice extends StatefulWidget {
  const _UnreadableNotice({required this.repository});
  final ParcelRepository repository;

  @override
  State<_UnreadableNotice> createState() => _UnreadableNoticeState();
}

class _UnreadableNoticeState extends State<_UnreadableNotice> {
  List<String> _ids = const [];
  StreamSubscription<List<String>>? _subscription;

  @override
  void initState() {
    super.initState();
    // A failure to load is already shown by the figures; this notice only adds what could not be read.
    _subscription = widget.repository.watchUnreadable().listen((ids) => setState(() => _ids = ids), onError: (Object _) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    if (ids.isEmpty) return const SizedBox.shrink();
    final shown = ids.take(3).join(', ');
    final more = ids.length > 3 ? ' and ${ids.length - 3} more' : '';
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.error),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                ids.length == 1
                    ? "1 parcel couldn't be read, so it is left out of the lists and totals (document $shown). Please contact support."
                    : "${ids.length} parcels couldn't be read, so they are left out of the lists and totals (documents $shown$more). Please contact support.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.stats, required this.widget});
  final DashboardStats stats;
  final DashboardScreen widget;

  @override
  Widget build(BuildContext context) {
    final cards = <_Card>[
      _Card('Total parcels', '${stats.totalParcels}', () => widget.onOpenParcels(DashboardLists.all)),
      _Card('Sent', '${stats.sent}', () => widget.onOpenParcels(DashboardLists.sent)),
      _Card('Returned', '${stats.returned}', () => widget.onOpenParcels(DashboardLists.returned)),
      _Card('Gift / Free', '${stats.freeGift}', () => widget.onOpenParcels(DashboardLists.freeGift)),
      _Card('Parcels with payment received', '${stats.paymentReceived}', () => widget.onOpenParcels(DashboardLists.paymentReceived)),
      _Card('Parcels pending payment', '${stats.pendingPayment}', () => widget.onOpenParcels(DashboardLists.pendingPayment)),
      _Card('Total received', formatRupees(stats.totalReceivedPaisa), widget.onOpenPayments),
      _Card('Total outstanding', formatRupees(stats.totalOutstandingPaisa), widget.onOpenPayments),
      _Card('Pay Later balance', formatRupees(stats.payLaterBalancePaisa), widget.onOpenPayments),
      _Card('Advance amount', formatRupees(stats.advancePaisa), widget.onOpenPayments),
      _Card('Reminders due today', '${stats.dueToday}', widget.onOpenReminders),
      _Card('Overdue', '${stats.overdue}', widget.onOpenReminders, urgent: stats.overdue > 0),
      if (stats.needsReview > 0) _Card('Need payment review', '${stats.needsReview}', widget.onOpenPayments, urgent: true),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 170).floor().clamp(1, 4);
        final width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final card in cards) SizedBox(width: width, child: _MetricCard(card: card))],
        );
      },
    );
  }
}

class _Card {
  const _Card(this.label, this.value, this.onTap, {this.urgent = false});
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool urgent;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.card});
  final _Card card;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${card.label}: ${card.value}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: card.urgent ? AppColors.error : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: card.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(card.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: card.urgent ? AppColors.error : AppColors.primaryDark)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(card.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.stats, required this.widget});
  final DashboardStats stats;
  final DashboardScreen widget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent parcels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        const SizedBox(height: AppSpacing.sm),
        if (stats.recent.isEmpty)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
            child: Text('No parcels yet. Add your first parcel.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          for (final parcel in stats.recent) ...[
            ParcelTile(parcel: parcel, onTap: () => widget.onOpenParcel(parcel.id)),
            const Divider(height: 1),
          ],
      ],
    );
  }
}
