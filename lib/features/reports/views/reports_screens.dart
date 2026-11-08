import 'package:flutter/material.dart';

import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../parcels/data/parcel_repository.dart';
import '../domain/reports.dart';
import '../viewmodel/report_view_model.dart';

/// The list of reports. Everything is on screen; nothing is exported.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.onOpen});
  final void Function(ReportType type) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              children: [
                for (final type in ReportType.values) ...[
                  ListTile(
                    minTileHeight: 64,
                    title: Text(
                      type.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(type.description),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => onOpen(type),
                  ),
                  const Divider(height: 1),
                ],
              ],
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.type.title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
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
    final today = _viewModel.today;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppDateField(
                        label: '${widget.type.dateLabel} from',
                        hint: 'Any day',
                        value: _viewModel.from,
                        firstDate: '2020-01-01',
                        lastDate:
                            '${int.parse(today.substring(0, 4)) + 5}${today.substring(4)}',
                        onChanged: (date) =>
                            _viewModel.setRange(from: date, to: _viewModel.to),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppDateField(
                        label: '${widget.type.dateLabel} to',
                        hint: 'Any day',
                        value: _viewModel.to,
                        firstDate: '2020-01-01',
                        lastDate:
                            '${int.parse(today.substring(0, 4)) + 5}${today.substring(4)}',
                        onChanged: (date) => _viewModel.setRange(
                          from: _viewModel.from,
                          to: date,
                        ),
                      ),
                      if (_viewModel.rangeProblem != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.sm,
                          ),
                          child: Text(
                            _viewModel.rangeProblem!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
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
                SliverList.separated(
                  itemCount: result.rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _ReportRowTile(
                    row: result.rows[index],
                    onTap: result.rows[index].parcelId == null
                        ? null
                        : () =>
                              widget.onOpenParcel(result.rows[index].parcelId!),
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
  const _ReportRowTile({required this.row, required this.onTap});
  final ReportRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  for (final line in row.lines.where((line) => line.isNotEmpty))
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
            ),
            if (row.trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                row.trailing!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: row.urgent ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final List<String> totals;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              for (final total in totals)
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
