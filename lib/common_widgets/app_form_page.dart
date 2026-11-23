import 'package:flutter/material.dart';

import '../design_system/foundations/spacing/app_spacing.dart';
import 'app_3d_decorations.dart';
import 'confirm_dialog.dart';
import 'liquid_glass.dart';

/// The frame of a full-page form: curved header, the page backdrop, a
/// scrolling [Form] of readable width, and a "Discard?" question when the
/// user leaves with unsaved changes ([canLeave] false).
class AppFormPage extends StatelessWidget {
  const AppFormPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.canLeave,
    required this.children,
    this.actions,
    this.discardTitle = 'Discard changes?',
    this.discardMessage = 'What you entered will be lost.',
  });
  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final bool canLeave;
  final List<Widget> children;
  final List<Widget>? actions;
  final String discardTitle;
  final String discardMessage;

  Future<void> _confirmDiscard(BuildContext context) async {
    final discard = await showConfirmDialog(
      context,
      title: discardTitle,
      message: discardMessage,
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!context.mounted || !discard) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard(context);
      },
      child: Scaffold(
        // The backdrop continues behind the header's curve.
        extendBodyBehindAppBar: true,
        appBar: appCurvedAppBar(
          toolbarHeight: AppBarTitle.heightFor(context),
          title: AppBarTitle(title, subtitle: subtitle),
          actions: actions,
        ),
        body: LiquidBackground(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
