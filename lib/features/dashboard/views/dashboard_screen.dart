import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_hero_header.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/count_badge.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/text.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../parcels/domain/parcel_search.dart';
import '../../parcels/views/parcels_screen.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../../reminders/viewmodel/reminder_list_view_model.dart';
import '../domain/dashboard_stats.dart';
import 'dashboard_widgets.dart';

/// Home: greeting, the money still to collect, quick actions, what needs attention, the figures grouped
/// by topic (each opens the list behind it) and the newest parcels. It also keeps the phone's reminders in step with the parcels.
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
    this.clock = const Clock(),
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
  final Clock clock;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Every parcel, live. The figures, the bell and the phone's reminders all come from this one list.
  late final _parcels = ReminderListViewModel(
    widget.parcelRepository,
    includeArchived: true,
    clock: widget.clock,
  );
  Set<int>? _plannedIds;
  bool _askedForPermission = false;

  @override
  void initState() {
    super.initState();
    _parcels.addListener(_keepPhoneInStep);
    // A notification that started the app opens its parcel once Home is up.
    final launchParcelId = widget.reminderScheduler.takeLaunchParcelId();
    if (launchParcelId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onOpenParcel(launchParcelId),
      );
    }
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
    if (before != null && ids.difference(before).isNotEmpty) {
      unawaited(_offerNotifications());
    }
  }

  Future<void> _offerNotifications() async {
    if (_askedForPermission ||
        await widget.reminderScheduler.areNotificationsEnabled() ||
        !mounted) {
      return;
    }
    _askedForPermission = true;
    final allow = await showConfirmDialog(
      context,
      title: 'Get payment reminders?',
      message: 'DelivTrack can remind you at 9:00 AM on the day a Pay Later payment is due. Allow notifications to turn this on.',
      confirmLabel: 'Allow',
    );
    if (allow) await widget.reminderScheduler.requestPermission();
  }

  /// Below this height the header and hero scroll with the page instead of
  /// staying fixed, so a short screen keeps room for the content.
  static const double _minHeightForFixedTop = 600;
  static const double _heroOverlap = AppSpacing.x3l;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidBackground(
        child: ListenableBuilder(
          listenable: _parcels,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final failed = _parcels.errorMessage != null;
              final stats = failed || _parcels.isLoading
                  ? null
                  : DashboardStats.from(_parcels.all, _parcels.today);
              final top = _top(stats);
              if (failed) {
                return Column(
                  children: [
                    top,
                    Expanded(
                      child: EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: "Couldn't load your figures",
                        message: _parcels.errorMessage,
                        actionLabel: 'Retry',
                        onAction: _parcels.retry,
                      ),
                    ),
                  ],
                );
              }
              final content = _content(stats);
              // Larger text makes the fixed top taller, so it needs more room.
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              if (constraints.maxHeight < _minHeightForFixedTop * textScale) {
                return _scroll(Column(children: [top, content]));
              }
              // Drawn bottom-up so the fixed top paints over the content.
              return Column(
                verticalDirection: VerticalDirection.up,
                children: [
                  Expanded(child: _scroll(content)),
                  top,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scroll(Widget child) {
    return RefreshIndicator(
      onRefresh: () async => _parcels.retry(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: child,
      ),
    );
  }

  /// Greeting header with the hero card overlapping its bottom edge.
  Widget _top(DashboardStats? stats) {
    final repository = widget.repository;
    final due = _parcels.reminders.dueCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<String?>(
          stream: repository.displayNameChanges,
          initialData: repository.displayName,
          builder: (context, snapshot) {
            final name = collapseSpaces(snapshot.data ?? '');
            final now = widget.clock.nowUtc().add(const Duration(hours: 5));
            final greeting = greetingForHour(now.hour);
            return AppHeroHeader(
              // A phone shows the name on its own line; wider screens
              // have room for one line.
              title: name.isEmpty
                  ? greeting
                  : MediaQuery.widthOf(context) < 600
                  ? '$greeting,\n$name'
                  : '$greeting, $name',
              subtitle: shortDateLine(now),
              icon: Icons.inventory_2_rounded,
              maxContentWidth: _maxWidth - 2 * AppSpacing.lg,
              bottomPadding: stats == null
                  ? AppSpacing.xl
                  : _heroOverlap + AppSpacing.md,
              actions: [
                AppHeroHeader.action(
                  tooltip: due == 0 ? 'Reminders' : 'Reminders, $due due',
                  icon: CountBadge(
                    count: due,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  onPressed: widget.onOpenReminders,
                ),
                AppHeroHeader.action(
                  tooltip: 'Log out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => confirmLogout(context, repository),
                ),
              ],
            );
          },
        ),
        if (stats != null)
          OverlapUp(
            overlap: _heroOverlap,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: DashboardHero(
                    outstandingPaisa: stats.totalOutstandingPaisa,
                    owingParcels: stats.owingParcels,
                    receivedPaisa: stats.totalReceivedPaisa,
                    onTap: widget.onOpenPayments,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static const double _maxWidth = 960;

  Widget _content(DashboardStats? stats) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UnreadableNotice(repository: widget.parcelRepository),
                if (stats == null)
                  const ListSkeleton()
                else
                  ..._sections(stats),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(DashboardStats stats) {
    return [
      DashboardQuickActions(
        onAddParcel: widget.onAddParcel,
        onSearch: () => widget.onOpenParcels(ParcelFilters.none),
      ),
      const SizedBox(height: AppSpacing.xl),
      const SectionTitle('Needs attention'),
      const SizedBox(height: AppSpacing.sm),
      AttentionCard(
        items: [
          AttentionItem(
            title: 'Overdue',
            subtitle: 'Pay Later payments past their date',
            count: stats.overdue,
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            onTap: widget.onOpenReminders,
          ),
          AttentionItem(
            title: 'Reminders due today',
            subtitle: 'Pay Later payments due today',
            count: stats.dueToday,
            icon: Icons.notifications_active_outlined,
            color: AppColors.pending,
            onTap: widget.onOpenReminders,
          ),
          AttentionItem(
            title: 'Awaiting handover',
            subtitle: 'Drafts to hand over',
            count: stats.awaitingHandover,
            icon: Icons.local_post_office_outlined,
            color: AppColors.pending,
            onTap: () => widget.onOpenParcels(DashboardLists.awaitingHandover),
          ),
          AttentionItem(
            title: 'Need payment review',
            subtitle: 'Returned parcels with money involved',
            count: stats.needsReview,
            icon: Icons.assignment_late_outlined,
            color: AppColors.error,
            onTap: widget.onOpenPayments,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      StatSection(
        title: 'Parcels overview',
        tiles: [
          StatTile(
            label: 'Total parcels',
            value: '${stats.totalParcels}',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
            onTap: () => widget.onOpenParcels(DashboardLists.all),
          ),
          StatTile(
            label: 'Sent',
            value: '${stats.sent}',
            icon: Icons.local_shipping_outlined,
            color: AppColors.primary,
            onTap: () => widget.onOpenParcels(DashboardLists.sent),
          ),
          StatTile(
            label: 'Returned',
            value: '${stats.returned}',
            icon: Icons.undo_rounded,
            color: AppColors.credit,
            onTap: () => widget.onOpenParcels(DashboardLists.returned),
          ),
          StatTile(
            label: 'Gift / Free',
            value: '${stats.freeGift}',
            icon: Icons.card_giftcard_outlined,
            color: AppColors.freeGift,
            onTap: () => widget.onOpenParcels(DashboardLists.freeGift),
          ),
          StatTile(
            label: 'Parcels with payment received',
            caption: 'Payment received',
            valueColor: AppColors.success,
            value: '${stats.paymentReceived}',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            onTap: () => widget.onOpenParcels(DashboardLists.paymentReceived),
          ),
          StatTile(
            label: 'Parcels pending payment',
            caption: 'Pending payment',
            valueColor: AppColors.pending,
            value: '${stats.pendingPayment}',
            icon: Icons.hourglass_bottom_rounded,
            color: AppColors.pending,
            onTap: () => widget.onOpenParcels(DashboardLists.pendingPayment),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      const SectionTitle('Money'),
      const SizedBox(height: AppSpacing.sm),
      MoneyCard(
        top: [
          StatTile(
            label: 'Total received',
            value: formatRupees(stats.totalReceivedPaisa),
            icon: Icons.payments_outlined,
            color: AppColors.success,
            valueColor: AppColors.primary,
            onTap: widget.onOpenPayments,
          ),
          StatTile(
            label: 'Pay Later balance',
            value: formatRupees(stats.payLaterBalancePaisa),
            icon: Icons.event_repeat_outlined,
            color: AppColors.credit,
            onTap: widget.onOpenPayments,
          ),
        ],
        bottom: StatTile(
          label: 'Advance amount',
          value: formatRupees(stats.advancePaisa),
          icon: Icons.savings_outlined,
          color: AppColors.advance,
          valueColor: AppColors.primary,
          onTap: widget.onOpenPayments,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Parcel counts and balances cover active parcels. Total received and Advance amount also include archived parcels.',
        style: TextStyle(fontSize: 12, color: AppColors.label),
      ),
      const SizedBox(height: AppSpacing.xl),
      _Recent(stats: stats, widget: widget),
    ];
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
    _subscription = widget.repository.watchUnreadable().listen(
      (ids) => setState(() => _ids = ids),
      onError: (Object _) {},
    );
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

class _Recent extends StatelessWidget {
  const _Recent({required this.stats, required this.widget});
  final DashboardStats stats;
  final DashboardScreen widget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Recent parcels',
          action: 'View all',
          onAction: () => widget.onOpenParcels(ParcelFilters.none),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (stats.recent.isEmpty)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'No parcels yet. Add your first parcel.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final parcel in stats.recent)
                ParcelTile(
                  parcel: parcel,
                  onTap: () => widget.onOpenParcel(parcel.id),
                ),
            ],
          ),
      ],
    );
  }
}
