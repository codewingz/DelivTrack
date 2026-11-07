import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../core/money/money.dart';
import 'app_field_label.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import '../utils/app_validators.dart';

/// Reusable input field adhering to DelivTrack design specifications.
/// Supports named constructors:
/// - [AppTextField] (general text)
/// - [AppTextField.name]
/// - [AppTextField.search]
/// - [AppTextField.email]
/// - [AppTextField.password]
/// - [AppTextField.confirmPassword]
/// - [AppTextField.amount]
/// - [AppTextField.weight]
/// - [AppTextField.phone]
/// - [AppTextField.multiline]
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? initialValue;
  final bool isRequired;
  final bool enabled;
  final bool readOnly;
  final bool isPassword;
  final int maxLines;
  final int? minLines;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  /// Shows a clear (x) button while text is present. Requires a [controller].
  final bool clearable;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.initialValue,
    this.isRequired = false,
    this.enabled = true,
    this.readOnly = false,
    this.isPassword = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.focusNode,
    this.autovalidateMode,
    this.clearable = false,
  }) : assert(!clearable || controller != null, 'clearable needs a controller');

  /// Search box with a leading search icon and a clear button.
  factory AppTextField.search({
    Key? key,
    required TextEditingController controller,
    String hint = 'Search',
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      hint: hint,
      clearable: true,
      textCapitalization: TextCapitalization.none,
      textInputAction: TextInputAction.search,
      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.label),
      inputFormatters: [LengthLimitingTextInputFormatter(60)],
      onChanged: onChanged,
    );
  }

  /// Name field (person, product...): word capitalization, 2-60 characters.
  factory AppTextField.name({
    Key? key,
    TextEditingController? controller,
    String label = 'Full Name',
    String hint = 'e.g. Muhammad Afzaal',
    IconData icon = Icons.person_outline_rounded,
    bool isRequired = true,
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      isRequired: isRequired,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      prefixIcon: Icon(icon, size: 20, color: AppColors.label),
      inputFormatters: [LengthLimitingTextInputFormatter(60)],
      validator: isRequired ? (value) => AppValidators.name(value, fieldName: label) : null,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Email field with email keyboard, lowercase formatting, and email validation.
  factory AppTextField.email({
    Key? key,
    TextEditingController? controller,
    String label = 'Email Address',
    String hint = 'e.g. name@company.com',
    String? helperText,
    bool isRequired = true,
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.none,
      prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.label),
      validator: (value) {
        final err = AppValidators.email(value, isRequired: isRequired);
        if (err != null) return err;
        return validator?.call(value);
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Password field with visibility toggle and minimum length validation.
  factory AppTextField.password({
    Key? key,
    TextEditingController? controller,
    String label = 'Password',
    String hint = 'Enter password',
    String? helperText,
    bool isRequired = true,
    bool enabled = true,
    int minLength = 6,
    TextInputAction textInputAction = TextInputAction.done,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      isPassword: true,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.label),
      validator: (value) {
        final err = AppValidators.password(value, isRequired: isRequired, minLength: minLength);
        if (err != null) return err;
        return validator?.call(value);
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Password confirmation: visibility toggle, must equal [passwordController]'s text.
  factory AppTextField.confirmPassword({
    Key? key,
    required TextEditingController passwordController,
    TextEditingController? controller,
    String label = 'Confirm Password',
    String hint = 'Re-enter password',
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      isRequired: true,
      enabled: enabled,
      isPassword: true,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: textInputAction,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.label),
      validator: (value) => AppValidators.confirmPassword(value, passwordController.text),
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Currency / Payment Amount field with Rs. prefix, decimal restrictions, and number keypad.
  factory AppTextField.amount({
    Key? key,
    TextEditingController? controller,
    String label = 'Amount (Rs.)',
    String hint = '0.00',
    String? helperText,
    bool isRequired = true,
    bool enabled = true,
    int minPaisa = 0,
    int maxPaisa = maxMoneyPaisa,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      prefixText: 'Rs. ',
      prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: AppColors.label),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        final err = AppValidators.amount(value, isRequired: isRequired, fieldName: label.replaceAll(' (Rs.)', ''), minPaisa: minPaisa, maxPaisa: maxPaisa);
        if (err != null) return err;
        return validator?.call(value);
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Weight field with 'kg' suffix and decimal numeric keypad.
  factory AppTextField.weight({
    Key? key,
    TextEditingController? controller,
    String label = 'Weight',
    String hint = '0.00',
    String? helperText,
    bool isRequired = false,
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      suffixText: 'kg',
      prefixIcon: const Icon(Icons.scale_outlined, size: 20, color: AppColors.label),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
      ],
      validator: (value) {
        final err = AppValidators.weight(value, isRequired: isRequired);
        if (err != null) return err;
        return validator?.call(value);
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Phone number field with phone keypad and length validation.
  factory AppTextField.phone({
    Key? key,
    TextEditingController? controller,
    String label = 'Phone Number',
    String hint = 'e.g. 03001234567',
    String? helperText,
    bool isRequired = true,
    bool enabled = true,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.label),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
        LengthLimitingTextInputFormatter(20),
      ],
      validator: (value) {
        final err = AppValidators.phone(value, isRequired: isRequired);
        if (err != null) return err;
        return validator?.call(value);
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      focusNode: focusNode,
    );
  }

  /// Multiline text area for remarks, return reasons, or addresses.
  factory AppTextField.multiline({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    String? helperText,
    bool isRequired = false,
    bool enabled = true,
    int minLines = 3,
    int maxLines = 5,
    int? maxLength,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      inputFormatters: maxLength == null ? null : [LengthLimitingTextInputFormatter(maxLength)],
      textCapitalization: TextCapitalization.sentences,
      validator: (value) {
        if (isRequired) {
          final err = AppValidators.required(value, fieldName: label ?? 'This field');
          if (err != null) return err;
        }
        return validator?.call(value);
      },
      onChanged: onChanged,
      focusNode: focusNode,
    );
  }

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _hasText = widget.controller?.text.isNotEmpty ?? false;
    if (widget.clearable) widget.controller!.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clearable) oldWidget.controller!.removeListener(_onTextChanged);
    if (widget.clearable) {
      widget.controller!.addListener(_onTextChanged);
      _hasText = widget.controller!.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    if (widget.clearable) widget.controller!.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller!.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AppFieldLabel(widget.label!, isRequired: widget.isRequired),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.initialValue,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: widget.isPassword ? _obscureText : false,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.isPassword ? 1 : widget.minLines,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
            ),
            helperText: widget.helperText,
            helperStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
            filled: true,
            fillColor: widget.enabled ? AppColors.surface : AppColors.disabled,
            constraints: const BoxConstraints(minHeight: 52),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            prefixIcon: widget.prefixIcon,
            prefixText: widget.prefixText,
            prefixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            suffixText: widget.suffixText,
            suffixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.label,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.clearable && _hasText
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.label),
                        onPressed: () {
                          widget.controller!.clear();
                          widget.onChanged?.call('');
                        },
                      )
                    : widget.suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.error, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
}
