import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'app_field_label.dart';
import 'app_text_field.dart';

/// A dropdown (built on `dropdown_button2`): shows the current choice in a field that looks like every
/// other input and opens a menu right under it. Use it instead of chips for three or more options.
/// Works in a [Form] ([validator] runs with the current value).
class AppDropdownField<T> extends StatefulWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final List<({T value, String label})> options;

  /// The current choice; null when nothing is chosen yet.
  final T? value;
  final ValueChanged<T> onChanged;
  final String? Function(T? value)? validator;
  final bool isRequired;
  final bool enabled;

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  late final _value = ValueNotifier<T?>(widget.value);

  @override
  void didUpdateWidget(AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value.value = widget.value;
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  static const _textStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final decoration = appInputDecoration(
      hint: widget.hint,
      enabled: widget.enabled,
    ).copyWith(contentPadding: EdgeInsets.zero);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFieldLabel(widget.label, isRequired: widget.isRequired),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField2<T>(
          valueListenable: _value,
          isExpanded: true,
          decoration: decoration,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: widget.validator == null
              ? null
              : (value) => widget.validator!(value),
          onChanged: widget.enabled
              ? (value) {
                  if (value != null) widget.onChanged(value);
                }
              : null,
          // The button shows the plain label; the open menu also ticks the current choice.
          selectedItemBuilder: (context) => [
            for (final option in widget.options)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  option.label,
                  style: _textStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final option in widget.options)
              DropdownItem<T>(
                value: option.value,
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        style: _textStyle.copyWith(
                          fontWeight: option.value == widget.value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: option.value == widget.value
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (option.value == widget.value)
                      const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ),
          ],
          // No extra padding: the border's 4 plus the menu's 16 side padding that the package adds to
          // the button already put the text where other fields have it (20).
          buttonStyleData: const FormFieldButtonStyleData(
            height: 52,
            padding: EdgeInsets.zero,
          ),
          iconStyleData: const IconStyleData(
            icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.label),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight: 288,
            offset: const Offset(0, -AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.border),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
          ),
        ),
      ],
    );
  }
}
