// Saves screenshots taken by integration tests (binding.takeScreenshot) to $SHOT_DIR.
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Platform.environment['SHOT_DIR'] ?? 'build/shots';
  await Directory(dir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('$dir/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
