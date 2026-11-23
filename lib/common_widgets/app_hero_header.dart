import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Tall green curved header: icon tile, "DELIVTRACK" eyebrow, [title] and an
/// optional [subtitle], with optional round [actions] at the end. Same
/// gradient and curve as [appCurvedAppBar]; use it at the top of a page that
/// has no toolbar. Covers the status bar.
class AppHeroHeader extends StatelessWidget {
  const AppHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_shipping_outlined,
    this.actions = const [],
    this.bottomPadding = AppSpacing.x4l,
    this.maxContentWidth = 480,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Buttons at the end of the title row; build them with [action].
  final List<Widget> actions;

  /// Space under the text; make it larger when a card overlaps the header.
  final double bottomPadding;
  final double maxContentWidth;

  /// A round translucent button for [actions].
  static Widget action({
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
      ),
      icon: icon,
    );
  }

  static const _curve = BorderRadius.vertical(bottom: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: _curve,
        boxShadow: [
          BoxShadow(
            color: Color(0x590B4633),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _curve,
        child: Stack(
          children: [
            // Soft decorative circle in the top corner.
            PositionedDirectional(
              end: -AppSpacing.x3l,
              top: -AppSpacing.x3l,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                MediaQuery.paddingOf(context).top + AppSpacing.xxl,
                AppSpacing.xl,
                bottomPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.mint.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: AppColors.mint.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Icon(
                                icon,
                                size: 24,
                                color: AppColors.mint,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DELIVTRACK',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                    color: AppColors.mint,
                                  ),
                                ),
                                // Owner's rule: the title is never cut or
                                // wrapped on its own; a long line shrinks to
                                // fit. Callers add a line break where wanted.
                                Semantics(
                                  header: true,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      title,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final action in actions) ...[
                            const SizedBox(width: AppSpacing.sm),
                            action,
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.brand100,
                          ),
                        ),
                      ],
                    ],
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
