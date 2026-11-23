import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../domain/reports.dart';
import '../viewmodel/report_view_model.dart';

/// Icon and colour of each report (the same colours as the statuses elsewhere).
({IconData icon, Color color}) _look(ReportType type) => switch (type) {
  ReportType.outstanding => (
    icon: Icons.hourglass_bottom_rounded,
    color: AppColors.pending,
  ),
  ReportType.paymentHistory => (
    icon: Icons.payments_outlined,
    color: AppColors.success,
  ),
  ReportType.returned => (icon: Icons.undo_rounded, color: AppColors.error),
  ReportType.freeGift => (
    icon: Icons.card_giftcard_outlined,
    color: AppColors.freeGift,
  ),
  ReportType.payLater => (
    icon: Icons.event_repeat_outlined,
    color: AppColors.credit,
  ),
  ReportType.productWise => (
    icon: Icons.inventory_2_outlined,
    color: AppColors.primary,
  ),
  ReportType.dateWise => (
    icon: Icons.calendar_today_outlined,
    color: AppColors.advance,
  ),
};

/// The list of reports. Everything is on screen; nothing is exported.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.onOpen});
  final void Function(ReportType type) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The backdrop continues behind the header's curve.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: AppBarTitle(
          'Reports',
          subtitle: '${ReportType.values.length} business & parcel reports',
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
                  children: [
                    for (final type in ReportType.values)
                      App3DCard(
                        glass: true,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          minTileHeight: 72,
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            AppSpacing.xs,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          leading: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _look(type).color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                _look(type).icon,
                                color: _look(type).color,
                                size: 22,
                              ),
                            ),
                          ),
                          title: Text(
                            type.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            type.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.label,
                          ),
                          onTap: () => onOpen(type),
                        ),
                      ),
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

/// One report: a date range, the rows, and the totals pinned at the bottom. A row opens its parcel.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.repository,
    required this.type,
    required this.onOpenParcel,
    this.clock = const Clock(),
  });
  final ParcelRepository repository;
  final ReportType type;
  final void Function(String parcelId) onOpenParcel;
  final Clock clock;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final _viewModel = ReportViewModel(
    widget.repository,
    widget.type,
    clock: widget.clock,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // The date range sits half over the header's bottom edge and stays put.
    // With large text or a short screen it scrolls with the rows.
    final pinRange = textScale <= 1.3 && MediaQuery.heightOf(context) >= 480;
    final rangeHeight = 80 + 30 * textScale;
    return Scaffold(
      // The backdrop continues behind the header's curve and the date range.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: AppBarTitle(widget.type.title, subtitle: 'Filter by date range'),
        bottomOverhang: pinRange ? rangeHeight / 2 + AppSpacing.sm : 0,
        bottom: pinRange
            ? PreferredSize(
                preferredSize: Size.fromHeight(rangeHeight + AppSpacing.sm),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: SizedBox(
                        height: rangeHeight,
                        child: ListenableBuilder(
                          listenable: _viewModel,
                          builder: (context, _) => _range(sideBySide: true),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: LiquidBackground(
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _body(showRange: !pinRange),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The two date fields under a small heading, in a glass card.
  Widget _range({required bool sideBySide}) {
    final today = _viewModel.today;
    final lastDate =
        '${int.parse(today.substring(0, 4)) + 5}${today.substring(4)}';
    final from = AppDateField(
      hint: 'From',
      value: _viewModel.from,
      firstDate: '2020-01-01',
      lastDate: lastDate,
      onChanged: (date) => _viewModel.setRange(from: date, to: _viewModel.to),
    );
    final to = AppDateField(
      hint: 'To',
      value: _viewModel.to,
      firstDate: '2020-01-01',
      lastDate: lastDate,
      onChanged: (date) => _viewModel.setRange(from: _viewModel.from, to: date),
    );
    return GlassSurface(
      radius: AppRadius.card,
      blurSigma: 12,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${widget.type.dateLabel} range'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: from),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: to),
                ],
              )
            else ...[
              from,
              const SizedBox(height: AppSpacing.sm),
              to,
            ],
          ],
        ),
      ),
    );
  }

  Widget _body({required bool showRange}) {
    if (_viewModel.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load the report",
        message: _viewModel.errorMessage,
        actionLabel: 'Retry',
        onAction: _viewModel.retry,
      );
    }
    if (_viewModel.paymentsError != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load the payments",
        message: _viewModel.paymentsError,
        actionLabel: 'Retry',
        onAction: _viewModel.retryPayments,
      );
    }
    final result = _viewModel.result;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (showRange)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: _range(sideBySide: false),
                  ),
                ),
              if (_viewModel.rangeProblem != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _viewModel.rangeProblem!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
              if (result == null && _viewModel.rangeProblem == null)
                const SliverToBoxAdapter(child: ListSkeleton())
              else if (result != null && result.rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'Nothing to report',
                    message: 'Nothing matches this report and date range.',
                  ),
                )
              else if (result != null)
                SliverPadding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  sliver: SliverList.builder(
                    itemCount: result.rows.length,
                    itemBuilder: (context, index) => _ReportRowTile(
                      type: widget.type,
                      row: result.rows[index],
                      onTap: result.rows[index].parcelId == null
                          ? null
                          : () => widget.onOpenParcel(
                              result.rows[index].parcelId!,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (result != null) _Totals(totals: result.totals),
      ],
    );
  }
}

class _ReportRowTile extends StatelessWidget {
  const _ReportRowTile({
    required this.type,
    required this.row,
    required this.onTap,
  });
  final ReportType type;
  final ReportRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Product-wise and date-wise rows show their figure as a chip at the end.
    final asChip =
        (type == ReportType.productWise && row.lines.length > 1) ||
        type == ReportType.dateWise;
    final chip = asChip ? row.lines.last : null;
    final lines = [
      for (final line
          in asChip ? row.lines.take(row.lines.length - 1) : row.lines)
        if (line.isNotEmpty) line,
    ];
    final amountColor = row.urgent
        ? AppColors.error
        : switch (type) {
            ReportType.paymentHistory => AppColors.primary,
            ReportType.outstanding || ReportType.payLater => AppColors.pending,
            _ => AppColors.textPrimary,
          };
    return App3DCard(
      glass: true,
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      // The figure moves under the text when both do not fit.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              for (final line in lines)
                Text(
                  line,
                  style: TextStyle(
                    fontSize: 13,
                    color: row.urgent
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (chip != null)
            StatusChip(label: chip, color: AppColors.primary)
          else if (row.trailing != null)
            Text(
              row.trailing!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: amountColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// The report's totals, pinned at the bottom on a glass bar.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final List<String> totals;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.glassSheetFill,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                for (final total in totals)
                  Text(
                    total,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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
