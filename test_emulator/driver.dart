// Driver for the emulator-backed repository tests: `flutter drive --driver=test_emulator/driver.dart
// --target=test_emulator/<name>_test.dart -d <android-emulator>` (see run_emulator_tests.sh).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
