import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/view_models/action_view_model.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'primary_button.dart';

/// Opens [builder]'s sheet (normally an [AppFormSheet]). Returns true when it was submitted.
Future<bool> showFormSheet(BuildContext context, WidgetBuilder builder) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
  return submitted ?? false;
}

/// The frame every small action sheet shares: title with a Close button, optional subtitle, the
/// fields, an error line and one submit button (optionally with a second button beside it). The form is validated first; [onSubmit] then runs once at a time (repeated
/// taps are ignored) and the sheet closes with true when it succeeds. An [AppFailure] thrown by
/// [onSubmit] is shown in the sheet, which stays open with what the user typed.
class AppFormSheet extends StatefulWidget {
  const AppFormSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.fields,
    this.subtitle,
    this.secondaryLabel,
    this.onSecondary,
    this.pinFooter = false,
  });

  final String title;
  final String? subtitle;
  final String submitLabel;
  final Future<void> Function() onSubmit;

  /// The form fields; they are disabled while [onSubmit] runs (`busy`).
  final List<Widget> Function(bool busy) fields;

  /// A second, quieter button beside the submit button (e.g. "Reset"); shown
  /// when both are given. It does not close the sheet.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Keeps the title and the buttons in place and scrolls only the fields
  /// between them, on a tinted background. For long sheets made of cards.
  final bool pinFooter;

  @override
  State<AppFormSheet> createState() => _AppFormSheetState();
}

class _AppFormSheetState extends State<AppFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _viewModel = ActionViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final done = await _viewModel.run(widget.onSubmit);
    if (!mounted || !done) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.closeButton,
                    foregroundColor: AppColors.label,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        );
        final fields = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final field in widget.fields(busy)) ...[
              field,
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_viewModel.errorMessage != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.lg,
                  ),
                  child: Text(
                    _viewModel.errorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
          ],
        );
        final submit = PrimaryButton(
          label: widget.submitLabel,
          isLoading: busy,
          onPressed: _submit,
        );
        final hasSecondary =
            widget.secondaryLabel != null && widget.onSecondary != null;
        final buttons = !hasSecondary
            ? submit
            : Row(
                children: [
                  FilledButton(
                    onPressed: busy ? null : widget.onSecondary,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 56),
                      backgroundColor: AppColors.brand50,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                    ),
                    child: Text(
                      widget.secondaryLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: submit),
                ],
              );

        // With large text the title and buttons grow tall, so everything
        // scrolls together instead.
        if (widget.pinFooter &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
          return Form(
            key: _formKey,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: header,
                  ),
                  Flexible(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        border: Border.symmetric(
                          horizontal: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          0,
                        ),
                        child: fields,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: buttons,
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xxl,
            0,
            AppSpacing.xxl,
            AppSpacing.xxl + keyboard,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: AppSpacing.xl),
                fields,
                const SizedBox(height: AppSpacing.sm),
                buttons,
              ],
            ),
          ),
        );
      },
    );
  }
}
