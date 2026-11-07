// Tap-to-call on the Android emulator: the phone has a dialer the app is allowed to see
// (the manifest's <queries> entry for the tel scheme). It does not place a call.
// Run: flutter test integration_test/dialer_test.dart -d <android-emulator>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tel: link can be handled by this phone', (t) async {
    expect(await canLaunchUrl(Uri(scheme: 'tel', path: '+923001111111')), isTrue);
  });
}
