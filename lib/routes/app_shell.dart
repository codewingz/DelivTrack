import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-tab frame around the main sections (Home, Parcels, Payments, Customers, More).
///
/// Deliberately not a Scaffold: each tab page has its own Scaffold, and a second, outer one would
/// make snackbars appear on the outer Scaffold, on top of the page's floating button.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
        NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Parcels',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              label: 'More',
            ),
          ],
        ),
      ],
    );
  }
}
