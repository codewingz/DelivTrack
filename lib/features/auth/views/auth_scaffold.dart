import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_hero_header.dart';
import '../../../common_widgets/app_logo.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';

/// Shared layout for auth screens: green [AppHeroHeader], logo, a card with
/// an optional [topLink], fields, inline error, primary [button] and an
/// optional [footer] link row, then the "Powered by" pill. Scrollable and
/// width-capped. Spacing follows the auth screen of the HTML prototype.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.formKey,
    required this.title,
    required this.fields,
    required this.button,
    this.footer,
    this.topLink,
    this.subtitle,
    this.errorMessage,
    this.successMessage,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
  final String? errorMessage;
  final String? successMessage;
  final Widget button;
  final Widget? footer;
  final Widget? topLink;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LiquidBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final header = AppHeroHeader(title: title, subtitle: subtitle);
            final content = _content();
            // Too short to keep the header fixed (a landscape phone, or the
            // keyboard with large text): let it scroll away with the content.
            if (constraints.maxHeight <
                _minHeightForFixedHeader *
                    MediaQuery.textScalerOf(context).scale(1)) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, content],
                ),
              );
            }
            // The header stays put; only the content under it scrolls. Drawn
            // bottom-up so the header (and its shadow) paints over the content.
            return Column(
              verticalDirection: VerticalDirection.up,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: content,
                  ),
                ),
                header,
              ],
            );
          },
        ),
      ),
    );
  }

  static const double _minHeightForFixedHeader = 480;

  Widget _content() {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: AppLogo(width: 144)),
                  const SizedBox(height: AppSpacing.md),
                  App3DCard(
                    glass: true,
                    radius: AppRadius.cardLarge,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (topLink != null) ...[
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: topLink,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        for (final field in fields) ...[
                          field,
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (errorMessage != null) ...[
                          _AuthMessage(errorMessage!, color: AppColors.error),
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
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          footer!,
                        ],
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

class _PoweredByPill extends StatelessWidget {
  const _PoweredByPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
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
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
