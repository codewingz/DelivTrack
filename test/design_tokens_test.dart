import 'dart:io';
import 'package:deliv_track/design_system/foundations/spacing/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppSpacing matches the approved scale', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.x3l,
        AppSpacing.x4l,
        AppSpacing.x5l,
        AppSpacing.x6l,
      ],
      [4, 8, 12, 16, 20, 24, 32, 40, 48, 64],
    );
  });

  test('screens and widgets use spacing/radius tokens, not raw numbers', () {
    final raw = RegExp(
      r'SizedBox\((height|width): \d|EdgeInsets\w*(\.\w+)?\([^)]*\b\d|BorderRadius\.circular\(\d',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!path.endsWith('.dart') || path.contains('design_system') || path.endsWith('firebase_options.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (raw.hasMatch(lines[i])) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'Use AppSpacing / AppRadius tokens:\n${offenders.join('\n')}');
  });
}
