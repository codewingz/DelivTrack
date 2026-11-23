import 'package:deliv_track/common_widgets/app_hero_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long title stays whole on one line and shrinks to fit', (
    t,
  ) async {
    const title = 'Good afternoon, Muhammad Afzaal Ahmed';
    await t.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppHeroHeader(
            title: title,
            subtitle: 'Mon, 23 Nov 2026',
            actions: [
              AppHeroHeader.action(
                tooltip: 'One',
                icon: const Icon(Icons.add),
                onPressed: () {},
              ),
              AppHeroHeader.action(
                tooltip: 'Two',
                icon: const Icon(Icons.add),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text(title), findsOneWidget);
    // One line of 22px text; a second line would be about twice as tall.
    expect(t.getSize(find.text(title)).height, lessThan(40));
    // Drawn inside the header's width.
    expect(t.getRect(find.text(title)).right, lessThanOrEqualTo(320));
  });
}
