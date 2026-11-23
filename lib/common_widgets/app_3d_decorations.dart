import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'liquid_glass.dart';

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
      BoxShadow(color: AppColors.cardBevel, offset: Offset(0, 4)),
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
    this.glass = false,
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

  /// See-through white (Liquid Glass) for pages with a [LiquidBackground].
  final bool glass;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);

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

    final surface = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    if (glass) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: GlassSurface(radius: radius, child: surface),
      );
    }
    return Container(
      margin: margin,
      decoration: app3DCardDecoration(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        radius: radius,
      ),
      child: surface,
    );
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

  /// How far [bottom] sticks out under the green area (e.g. half a search box).
  double bottomOverhang = 0,
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
    flexibleSpace:
        flexibleSpace ??
        Container(
          margin: EdgeInsets.only(bottom: bottomOverhang),
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

/// Title for [appCurvedAppBar] with an optional line under it and an optional
/// icon tile before it. Give the bar [heightFor] as its toolbar height.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.title, {super.key, this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Toolbar height that fits the two lines at the current text size.
  static double heightFor(BuildContext context) =>
      24 + 48 * MediaQuery.textScalerOf(context).scale(1);

  @override
  Widget build(BuildContext context) {
    final text = subtitle == null
        ? Text(title)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.brand100),
              ),
            ],
          );
    if (icon == null) return text;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: 20, color: AppColors.mint),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: text),
      ],
    );
  }
}

/// A small two-line figure at the end of a curved app bar (e.g. "OUTSTANDING
/// Rs. 2,000"). Use it in `actions`.
class AppBarStatPill extends StatelessWidget {
  const AppBarStatPill({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.mint,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          BoxShadow(color: AppColors.fabBevel, offset: Offset(0, 4)),
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
                color:
                    iconBackground ??
                    (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
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
