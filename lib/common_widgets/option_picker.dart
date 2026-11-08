import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// The list behind a dropdown-style [AppSelectField]: a sheet with one row per option, the current
/// choice ticked. Returns the chosen value, or null when dismissed. Long lists scroll.
Future<T?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label})> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.heightOf(context) * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    minTileHeight: 48,
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    title: Text(option.label),
                    selected: option.value == selected,
                    selectedColor: AppColors.primary,
                    trailing: option.value == selected
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(option.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
