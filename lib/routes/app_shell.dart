import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';

/// Bottom-tab frame around the main sections (Home, Parcels, Payments, Customers, More).
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
    (icon: Icons.menu_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    // Same colours the Material tab bar used: bar surface, pill, active and inactive content.
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // The tab bar below already handles the bottom system inset.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: navigationShell,
          ),
        ),
        ColoredBox(
          color: scheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              // Labels stop growing at 1.3x, as Material's own tab bar does, and the row shrinks
              // to fit very narrow or very large settings rather than overflowing.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: GNav(
                        selectedIndex: navigationShell.currentIndex,
                        onTabChange: (index) => navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        ),
                        gap: AppSpacing.xs,
                        iconSize: AppSpacing.xxl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        tabBorderRadius: AppRadius.hero,
                        color: scheme.onSurfaceVariant,
                        activeColor: scheme.onSecondaryContainer,
                        tabBackgroundColor: scheme.secondaryContainer,
                        textStyle: TextStyle(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }
}
