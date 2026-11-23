import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'liquid_glass.dart';

/// Asks the user to confirm an action in a glass dialog. Returns true only
/// when they confirm. [icon] adds a small tile above the title.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final accent = destructive ? AppColors.error : AppColors.primary;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: GlassSurface(
          radius: AppRadius.cardLarge,
          blurSigma: 16,
          fill: AppColors.glassDialogFill,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(icon, color: accent, size: 24),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Two buttons of the same size, side by side.
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: AppColors.label,
                          backgroundColor: AppColors.glassFill,
                          side: const BorderSide(color: AppColors.glassEdge),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      // A filled 3D button: gradient (or red) with a ledge.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: destructive ? AppColors.error : null,
                          gradient: destructive
                              ? null
                              : AppColors.primaryBtnGradient,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: destructive
                                  ? AppColors.errorBevel
                                  : AppColors.btnBevel,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            confirmLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
