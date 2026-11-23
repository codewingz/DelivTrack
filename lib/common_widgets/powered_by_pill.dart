import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// The "Powered by CodeWingz" pill at the foot of a page.
class PoweredByPill extends StatelessWidget {
  const PoweredByPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        // Same soft shadow + solid ledge as the 3D cards.
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(color: AppColors.cardBevel, offset: Offset(0, 4)),
        ],
      ),
      child: const Text.rich(
        TextSpan(
          text: 'Powered by  ',
          children: [
            TextSpan(
              text: 'CodeWingz',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
