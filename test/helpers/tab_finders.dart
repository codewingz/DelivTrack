import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

/// The bottom-bar button for [label]. Only the selected tab shows its label as text, so the
/// others cannot be found with `find.text`.
Finder tabButton(String label) => find.byWidgetPredicate(
  (widget) => widget is GButton && widget.text == label,
  description: 'bottom tab "$label"',
);
