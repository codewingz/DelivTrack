import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_text_field.dart';

/// A read-only field that shows the current choice and opens a picker when tapped.
/// The picker itself is up to the caller ([onTap]); the new choice is passed back through
/// the parent's state ([displayText] changes).
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.displayText,
    required this.onTap,
    this.validator,
    this.isRequired = false,
    this.enabled = true,
    this.icon = Icons.arrow_drop_down_rounded,
  });

  final String label;
  final String hint;

  /// Text of the current choice; null or empty when nothing is chosen.
  final String? displayText;
  final VoidCallback onTap;

  /// Runs on form validation; return an error message or null.
  final String? Function()? validator;
  final bool isRequired;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      // New text -> new field state, so the shown choice always matches.
      key: ValueKey(displayText),
      label: label,
      hint: hint,
      initialValue: displayText ?? '',
      isRequired: isRequired,
      enabled: enabled,
      readOnly: true,
      onTap: enabled ? onTap : null,
      suffixIcon: Icon(icon, color: AppColors.label),
      maxLines: 1,
      validator: validator == null ? null : (_) => validator!(),
    );
  }
}
