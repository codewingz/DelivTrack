import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] matches something (or fails after [seconds]).
Future<void> pumpUntil(
  WidgetTester t,
  Finder finder, {
  int seconds = 12,
}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// Pumps frames until [finder] matches nothing (or fails after [seconds]).
Future<void> pumpUntilGone(
  WidgetTester t,
  Finder finder, {
  int seconds = 12,
}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Still present: $finder');
}

/// Taps [target] after scrolling it into view, with a frame for layout in between.
Future<void> tapVisible(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.pump();
  await t.tap(target);
}

/// Focuses a text field like a user would, then types (typing before focus settles can be lost).
Future<void> typeInto(WidgetTester t, Finder field, String text) async {
  await t.ensureVisible(field);
  await t.pump();
  await t.tap(field);
  await t.pump(const Duration(milliseconds: 200));
  await t.enterText(field, text);
  await t.pump(); // let the screen redraw with the new value
}
