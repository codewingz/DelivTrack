import 'package:flutter/material.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Small colored label for a status (Draft, Sent, Pending ...). The word carries the meaning;
/// color is only a hint, so it is never the only signal.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ),
    );
  }
}
