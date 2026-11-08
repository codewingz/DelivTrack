import 'package:deliv_track/common_widgets/app_text_field.dart';
import 'package:deliv_track/features/auth/views/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Widths/heights (logical px) from AGENTS.md width classes plus short landscape.
const _sizes = <Size>[
  Size(320, 568), // XS
  Size(393, 852), // SM
  Size(700, 900), // MD
  Size(1100, 800), // LG
  Size(640, 300), // short landscape
];
const _textScales = <double>[1.0, 1.3, 2.0];

Future<void> _pump(
  WidgetTester t,
  Size size,
  double scale,
  Widget child,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    ),
  );
  await t.pump(const Duration(seconds: 2));
}

void main() {
  for (final size in _sizes) {
    for (final scale in _textScales) {
      testWidgets('SplashScreen has no overflow at $size, text x$scale', (
        t,
      ) async {
        await _pump(t, size, scale, const SplashScreen());
        expect(t.takeException(), isNull);
        expect(find.text('Parcel & Payment Manager'), findsOneWidget);
      });

      testWidgets(
        'AppTextField long label has no overflow at $size, text x$scale',
        (t) async {
          await _pump(
            t,
            size,
            scale,
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextField.weight(
                  label: 'Actual packed parcel weight from the post office slip (kg)',
                  isRequired: true,
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull);
          expect(
            t.getSize(find.byType(TextFormField)).height,
            greaterThanOrEqualTo(52),
          );
        },
      );
    }
  }
}
