import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../common_widgets/liquid_glass.dart';
import '../constants/app_colors.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Bottom-tab frame around the main sections (Home, Parcels, Payments, Customers, More).
///
/// The bar is a floating glass pill on a strip of the page backdrop under the pages.
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
    return Column(
      children: [
        // The strip below already handles the bottom system inset.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: navigationShell,
          ),
        ),
        // The pill floats on a strip of the page backdrop. Pages end above
        // it, so their lists, Add buttons, messages and sheets are never
        // under the bar.
        ColoredBox(
          color: AppColors.liquidBase,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _dockMaxWidth),
                  child: _dock(),
                ),
              ),
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
