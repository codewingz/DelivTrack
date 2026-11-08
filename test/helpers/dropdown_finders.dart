import 'package:deliv_track/common_widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The [AppDropdownField] with this [label].
Finder dropdown(String label) => find.byWidgetPredicate(
  (widget) => widget is AppDropdownField && widget.label == label,
  description: 'dropdown "$label"',
);

/// The field itself (what the user taps), inside [dropdown].
Finder dropdownButton(String label) =>
    find.descendant(of: dropdown(label), matching: find.byType(InputDecorator));

/// Opens the dropdown with [label] and picks [option] from its menu (scrolling the menu if needed).
Future<void> chooseOption(WidgetTester t, String label, String option) async {
  await t.ensureVisible(dropdownButton(label));
  await t.pumpAndSettle();
  // The chosen option is also shown on the field itself, so count what is there before the menu opens.
  final before = find.text(option).evaluate().length;
  await t.tap(dropdownButton(label));
  await t.pumpAndSettle();
  // The menu builds its rows lazily: scroll it until the option appears.
  for (
    var i = 0;
    i < 20 && find.text(option).evaluate().length <= before;
    i++
  ) {
    await t.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await t.pumpAndSettle();
  }
  // The open menu is the top-most route, so its entry is the last one with this text.
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

/// The text the dropdown currently shows (its chosen option), or null when nothing is chosen.
bool dropdownShows(String label, String option) => find
    .descendant(of: dropdown(label), matching: find.text(option))
    .evaluate()
    .isNotEmpty;
