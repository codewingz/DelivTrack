import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Placeholder rows shown while a list loads. Place it inside a scrollable.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 5});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
