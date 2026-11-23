import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../common_widgets/liquid_glass.dart';
import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Bottom-tab frame around the main sections (Home, Parcels, Payments, Customers, More).
///
/// The bar is a floating glass pill drawn over the pages; there is no strip behind it.
///
/// Deliberately not a Scaffold: each tab page has its own Scaffold, and a second, outer one would
/// make snackbars appear on the outer Scaffold, on top of the page's floating button.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.local_shipping_outlined, label: 'Parcels'),
    (icon: Icons.payments_outlined, label: 'Payments'),
    (icon: Icons.people_outline_rounded, label: 'Customers'),
    (icon: Icons.grid_view_outlined, label: 'More'),
  ];

  static const double _dockHeight = 60;
  static const double _dockMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The pill floats over the pages, which run to the bottom of the screen
    // and scroll under it. This is the room they keep free at the bottom (as
    // if it were a system inset) so the end of a list, an Add button or a
    // message is never left under the pill. With the keyboard up the pill is
    // behind it and nothing is reserved.
    final reserved = media.viewInsets.bottom > 0
        ? 0.0
        : media.padding.bottom + _dockHeight + 2 * AppSpacing.md;
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: reserved),
              // A page's Add button and messages are placed from this one.
              viewPadding: media.viewPadding.copyWith(bottom: reserved),
            ),
            child: navigationShell,
          ),
        ),
        PositionedDirectional(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: media.padding.bottom + AppSpacing.md,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _dockMaxWidth),
              child: _dock(),
            ),
          ),
        ),
      ],
    );
  }

  /// The floating glass pill with the five tabs.
  Widget _dock() {
    return GlassSurface(
      key: const Key('app-dock'),
      radius: AppRadius.pill,
      // Content scrolls behind the pill, so it is real blurred glass.
      blurSigma: 14,
      ledgeColor: AppColors.dockLedge,
      ledgeHeight: 5,
      child: SizedBox(
        height: _dockHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          // Labels stop growing at 1.3x, as Material's own tab bar does, and the row shrinks
          // to fit very narrow or very large settings rather than overflowing.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: GNav(
                    selectedIndex: navigationShell.currentIndex,
                    onTabChange: (index) => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                    gap: AppSpacing.xs,
                    iconSize: AppSpacing.xxl,
                    // Narrow enough for all five to keep their full 48 height
                    // inside the pill on a 360-wide phone.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.md,
                    ),
                    tabBorderRadius: AppRadius.pill,
                    color: AppColors.textSecondary,
                    activeColor: AppColors.primaryDark,
                    tabBackgroundColor: AppColors.brand100,
                    textStyle: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabs: [
                      for (final tab in _tabs)
                        GButton(icon: tab.icon, text: tab.label),
                    ],
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
