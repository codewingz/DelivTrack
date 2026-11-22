import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Standard 3D tactile card decoration matching the V2 3D Liquid Glass design system.
BoxDecoration app3DCardDecoration({
  Color backgroundColor = AppColors.surface,
  Color borderColor = AppColors.border,
  double radius = 20.0,
  Color? stripeColor,
  double stripeWidth = 5.0,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: 1.0),
    boxShadow: const [
      // Soft ambient drop shadow
      BoxShadow(
        color: AppColors.cardShadow,
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
      // 3D solid tactile bottom bevel ledge
      BoxShadow(
        color: AppColors.cardBevel,
        offset: Offset(0, 4),
      ),
    ],
  );
}

/// An elevated white card with 3D tactile bottom bevel and optional left colored accent stripe.
class App3DCard extends StatelessWidget {
  const App3DCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.stripeColor,
    this.stripeWidth = 5.0,
    this.onTap,
    this.radius = 20.0,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? stripeColor;
  final double stripeWidth;
  final VoidCallback? onTap;
  final double radius;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (stripeColor != null) {
      content = Stack(
        children: [
          content,
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: stripeWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(radius),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final card = Container(
      margin: margin,
      decoration: app3DCardDecoration(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        radius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: content,
              ),
      ),
    );

    return card;
  }
}

/// 3D Curved AppBar matching DelivTrack V2.
/// Keeps tests passing (as it returns a genuine [AppBar]) while applying the 3D curved gradient style.
AppBar appCurvedAppBar({
  required Widget title,
  Widget? leading,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  double toolbarHeight = kToolbarHeight,
  bool automaticallyImplyLeading = true,
  Widget? flexibleSpace,
}) {
  return AppBar(
    title: title,
    leading: leading,
    actions: actions,
    bottom: bottom,
    toolbarHeight: toolbarHeight,
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    flexibleSpace: flexibleSpace ??
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x590B4633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
        ),
  );
}

/// 3D Mint Floating Action Button (+ Add Parcel / + Add Customer / + Add Product).
class MintFabButton extends StatelessWidget {
  const MintFabButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.mintFabGradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [
          BoxShadow(
            color: AppColors.fabBevel,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x470B4633),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: AppColors.brand900),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D Metric Tile (e.g. Total parcels, Sent, Returned, etc.)
class TactileMetricCard extends StatelessWidget {
  const TactileMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return App3DCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBackground ?? (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
