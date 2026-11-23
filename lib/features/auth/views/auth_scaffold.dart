import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_logo.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';

/// Shared layout for auth screens: green header (icon, title, subtitle),
/// optional logo, a card with fields, inline error, primary [button] and a
/// [footer] link row, then the "Powered by" pill. Scrollable and width-capped.
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
    this.successMessage,
    this.showLogo = false,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final String? errorMessage;
  final String? successMessage;
  final Widget button;
  final Widget footer;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthHeader(title: title, subtitle: subtitle),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showLogo) ...[
                            const Align(child: AppLogo(width: 160)),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          App3DCard(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final field in fields) ...[
                                  field,
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                if (errorMessage != null) ...[
                                  _AuthMessage(
                                    errorMessage!,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                if (successMessage != null) ...[
                                  _AuthMessage(
                                    successMessage!,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                button,
                                const SizedBox(height: AppSpacing.sm),
                                footer,
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const Align(child: _PoweredByPill()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xxl,
        top + AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.x3l,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.cardLarge + AppSpacing.sm),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const ExcludeSemantics(
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 32,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DELIVTRACK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.mint,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.brand100,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PoweredByPill extends StatelessWidget {
  const _PoweredByPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        // Same soft shadow + solid ledge as the 3D cards.
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(color: AppColors.cardBevel, offset: Offset(0, 4)),
        ],
      ),
      child: const Text.rich(
        TextSpan(
          text: 'Powered by  ',
          children: [
            TextSpan(
              text: 'CodeWingz',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

/// "Already have an account? Log in" style row that wraps instead of overflowing.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
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
