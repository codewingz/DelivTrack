import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/time/pakistan_time.dart';
import 'app_text_field.dart';

/// A read-only field that opens a date picker. The value is a "yyyy-MM-dd" string (or null).
/// Shows a clear button when a date is set, so an optional date can be removed again.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.hint = 'Select a date',
    this.enabled = true,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Earliest and latest selectable days, as "yyyy-MM-dd".
  final String firstDate;
  final String lastDate;
  final String hint;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final first = DateTime.parse(firstDate);
    final last = DateTime.parse(lastDate);
    final current = value == null ? first : DateTime.parse(value!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    onChanged('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      key: ValueKey(value),
      label: label,
      hint: hint,
      initialValue: value == null ? '' : formatDate(value!),
      enabled: enabled,
      readOnly: true,
      onTap: enabled ? () => _pick(context) : null,
      prefixIcon: const Icon(Icons.event_rounded, size: 20, color: AppColors.label),
      suffixIcon: value == null
          ? null
          : IconButton(
              tooltip: 'Clear date',
              icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.label),
              onPressed: enabled ? () => onChanged(null) : null,
            ),
    );
  }
}
