import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'app_field_label.dart';

/// Pick one option from a few, shown as wrapping chips. Works inside a [Form] (validator supported).
class AppChoiceField<T> extends FormField<T> {
  AppChoiceField({
    super.key,
    required List<({T value, String label})> options,
    required ValueChanged<T> onChanged,
    String? label,
    bool isRequired = false,
    super.initialValue,
    super.validator,
    super.enabled,
  }) : super(
          // Re-check after every choice, so a "Select ..." error goes away once the user fixes it.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                AppFieldLabel(label, isRequired: isRequired),
                const SizedBox(height: AppSpacing.sm),
              ],
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: state.value == option.value,
                      onSelected: enabled
                          ? (_) {
                              state.didChange(option.value);
                              onChanged(option.value);
                            }
                          : null,
                    ),
                ],
              ),
              if (state.errorText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.errorText!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ],
            ],
          ),
        );
}
