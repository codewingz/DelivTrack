import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// The small uppercase heading above a group of cards or rows, with an
/// optional text action at the end ("See all").
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(
    this.text, {
    super.key,
    this.action,
    this.onAction,
    this.padding = EdgeInsetsDirectional.zero,
  });
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsDirectional padding;

  /// The space around a heading that sits between two groups of rows.
  static const betweenGroups = EdgeInsetsDirectional.fromSTEB(
    AppSpacing.xs,
    AppSpacing.xl,
    AppSpacing.xs,
    AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.label,
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
    ),
  );
}
