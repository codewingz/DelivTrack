import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';

/// Building blocks of the Home screen. Home reads top to bottom by importance: who and when, the money
/// still to collect (the one hero), what needs attention, then the figures grouped by topic.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Good morning" / "Good afternoon" / "Good evening" for a Pakistan-time hour (0-23).
String greetingForHour(int hour) => hour < 12
    ? 'Good morning'
    : hour < 17
    ? 'Good afternoon'
    : 'Good evening';

/// "Sun, 8 Nov" for the Pakistan calendar date of [pakistanNow] (a UTC+5 instant expressed as UTC).
String shortDateLine(DateTime pakistanNow) =>
    '${_weekdays[pakistanNow.weekday - 1]}, ${pakistanNow.day} ${_months[pakistanNow.month - 1]}';

/// Number of columns for a grid of tiles: tiles keep a readable width and fall back to a single column as
/// the text size grows (nothing is clipped or scaled down).
int tileColumns(BuildContext context, double width, {double minTile = 150}) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return (width / (minTile * scale)).floor().clamp(1, 4);
}

class DashboardGreeting extends StatelessWidget {
  const DashboardGreeting({
    super.key,
    required this.name,
    required this.pakistanNow,
  });
  final String name;

  /// The current Pakistan time, expressed as a UTC [DateTime] (UTC + 5 hours).
  final DateTime pakistanNow;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingForHour(pakistanNow.hour);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shortDateLine(pakistanNow),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name.isEmpty ? greeting : '$greeting, $name',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

/// The one hero: what is still to be collected, with how much was already received beside it.
class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.outstandingPaisa,
    required this.owingParcels,
    required this.receivedPaisa,
    required this.onTap,
  });
  final int outstandingPaisa;
  final int owingParcels;
  final int receivedPaisa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final billed = outstandingPaisa + receivedPaisa;
    final receivedShare = billed <= 0 ? 0.0 : receivedPaisa / billed;
    final percentage = billed <= 0 ? 0 : (receivedShare * 100).round();
    final owingText = owingParcels == 0
        ? 'Nothing is waiting for payment'
        : '$owingParcels ${owingParcels == 1 ? 'parcel' : 'parcels'} awaiting payment';
    return Semantics(
      button: true,
      label: 'Total outstanding: ${formatRupees(outstandingPaisa)}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          gradient: AppColors.heroGradient,
          border: Border.all(color: const Color(0x991D7A5B), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6B073325),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0xFF06291E),
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Outstanding to collect',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                        ),
                        child: Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    formatRupees(outstandingPaisa),
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    owingText,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  if (billed > 0) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            ColoredBox(
                              color: Colors.white.withValues(alpha: 0.16),
                              child: const SizedBox.expand(),
                            ),
                            FractionallySizedBox(
                              widthFactor: receivedShare.clamp(0.0, 1.0),
                              child: const ColoredBox(
                                color: AppColors.mint,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const _LegendDot(color: AppColors.mint),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Received ${formatRupees(receivedPaisa)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: const SizedBox(width: AppSpacing.sm, height: AppSpacing.sm),
  );
}

/// The two quick actions under the hero. They stack on a narrow screen or a large text size.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    required this.onAddParcel,
    required this.onSearch,
  });
  final VoidCallback onAddParcel;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final add = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.primary,
        shadowColor: AppColors.btnBevel,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      onPressed: onAddParcel,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Parcel',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    final search = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: Color(0xFFDCE6E0)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      onPressed: onSearch,
      icon: const Icon(Icons.search_rounded),
      label: const Text(
        'Search',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (tileColumns(context, constraints.maxWidth, minTile: 160) < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              add,
              const SizedBox(height: AppSpacing.md),
              search,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: add),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: search),
          ],
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
    ],
  );
}

/// One line of the "Needs attention" list.
class AttentionItem {
  const AttentionItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// What needs the owner's attention now (only items with something in them), or a calm "all clear".
class AttentionCard extends StatelessWidget {
  const AttentionCard({super.key, required this.items});
  final List<AttentionItem> items;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final item in items)
        if (item.count > 0) item,
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.cardBevel,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        clipBehavior: Clip.antiAlias,
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.brand50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.brand800, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Text(
                        'All caught up. Nothing needs your attention.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFEEF3F0)),
                    _AttentionRow(item: shown[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});
  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title}: ${item.count}',
      hint: item.subtitle,
      excludeSemantics: true,
      child: InkWell(
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: AppSpacing.x4l,
                    height: AppSpacing.x4l,
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One figure: an icon chip in its status color, the number and what it counts.
class StatTile {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// A titled group of figures in a grid (a last odd tile takes the full width).
class StatSection extends StatelessWidget {
  const StatSection({super.key, required this.title, required this.tiles});
  final String title;
  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = tileColumns(context, constraints.maxWidth);
            final gap = AppSpacing.md * (columns - 1);
            final width = (constraints.maxWidth - gap) / columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final (index, tile) in tiles.indexed)
                  SizedBox(
                    width:
                        columns == 2 &&
                            index == tiles.length - 1 &&
                            tiles.length.isOdd
                        ? constraints.maxWidth
                        : width,
                    child: _StatTileView(tile: tile),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatTileView extends StatelessWidget {
  const _StatTileView({required this.tile});
  final StatTile tile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tile.label}: ${tile.value}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.cardBevel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tile.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: tile.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: SizedBox(
                          width: AppSpacing.x3l,
                          height: AppSpacing.x3l,
                          child: Icon(tile.icon, color: tile.color, size: 20),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          tile.value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tile.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white card that groups rows (the recent parcels), matching the attention list.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          children[i],
        ],
      ],
    ),
  );
}
