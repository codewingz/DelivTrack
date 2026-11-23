import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Label above a form field, with a red * when required. Wraps instead of overflowing.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.label, {super.key, this.isRequired = false});
  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    // "(optional)" at the end is written lighter than the label itself.
    const optional = ' (optional)';
    final hasOptional = label.endsWith(optional);
    return Text.rich(
      TextSpan(
        text: hasOptional
            ? label.substring(0, label.length - optional.length)
            : label,
        children: [
          if (hasOptional)
            const TextSpan(
              text: optional,
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
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
