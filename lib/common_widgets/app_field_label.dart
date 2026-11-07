import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Label above a form field, with a red * when required. Wraps instead of overflowing.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.label, {super.key, this.isRequired = false});
  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
        ],
      ),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.label,
        letterSpacing: 0.2,
      ),
    );
  }
}
