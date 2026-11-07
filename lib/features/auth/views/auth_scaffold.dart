import 'package:flutter/material.dart';
import '../../../common_widgets/app_logo.dart';
import '../../../constants/app_colors.dart';

/// Shared layout for auth screens: scrollable, width-capped, logo + title,
/// fields, inline error, primary [button] and a [footer] link row.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.formKey,
    required this.title,
    required this.fields,
    required this.button,
    required this.footer,
    this.subtitle,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final String? errorMessage;
  final Widget button;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(child: AppLogo(width: 160)),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 24),
                    for (final field in fields) ...[field, const SizedBox(height: 16)],
                    if (errorMessage != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    button,
                    const SizedBox(height: 16),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Log in" style row that wraps instead of overflowing.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({super.key, required this.prompt, required this.action, required this.onPressed});

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
