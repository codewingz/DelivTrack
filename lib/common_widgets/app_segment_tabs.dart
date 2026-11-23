import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// One tab of [AppSegmentTabs]: its label, how many items it holds and what
/// choosing it does.
typedef AppSegmentTab = ({
  String label,
  int count,
  bool selected,
  VoidCallback onTap,
});

/// A row of equal tabs, each showing its count ("Active (5)"), with the
/// selected one raised in white. Use it to switch a list between two or three
/// groups.
class AppSegmentTabs extends StatelessWidget {
  const AppSegmentTabs({super.key, required this.tabs});
  final List<AppSegmentTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab.selected,
                child: Material(
                  color: tab.selected ? AppColors.surface : Colors.transparent,
                  elevation: tab.selected ? 1 : 0,
                  shadowColor: AppColors.cardBevel,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: tab.onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Text(
                            '${tab.label} (${tab.count})',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: tab.selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: tab.selected
                                  ? AppColors.primary
                                  : AppColors.label,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
