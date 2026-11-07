import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/view_models/action_view_model.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'primary_button.dart';

/// Opens [builder]'s sheet (normally an [AppFormSheet]). Returns true when it was submitted.
Future<bool> showFormSheet(BuildContext context, WidgetBuilder builder) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: builder,
  );
  return submitted ?? false;
}

/// The frame every small action sheet shares: title, optional subtitle, the fields, an error line
/// and one submit button. The form is validated first; [onSubmit] then runs once at a time (repeated
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
  });

  final String title;
  final String? subtitle;
  final String submitLabel;
  final Future<void> Function() onSubmit;

  /// The form fields; they are disabled while [onSubmit] runs (`busy`).
  final List<Widget> Function(bool busy) fields;

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
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(widget.subtitle!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: AppSpacing.xl),
                for (final field in widget.fields(busy)) ...[field, const SizedBox(height: AppSpacing.lg)],
                if (_viewModel.errorMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
                      child: Text(
                        _viewModel.errorMessage!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(label: widget.submitLabel, isLoading: busy, onPressed: _submit),
              ],
            ),
          ),
        );
      },
    );
  }
}
