import 'package:flutter/material.dart';

/// A small count marker on top of [child] (an icon): hidden when [count] is 0.
///
/// The count is a one- or two-digit number inside a fixed-size marker, so it ignores the user's text
/// size. Scaled text would make the marker grow over the icon it labels. (Documented, individually
/// justified exception to the "text always scales" rule in AGENTS.md; the child is not affected.)
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: MediaQuery.withNoTextScaling(child: Text('$count')),
      child: child,
    );
  }
}
