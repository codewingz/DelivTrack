// Takes screenshots of the real app (Android emulator + Firebase emulators) for visual review.
// Run via flutter drive; see AGENTS.md "Verification commands".
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/ui_shots_test.dart \
//     -d emulator-5554 --dart-define=SHOT_TAG=phone
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _tag = String.fromEnvironment('SHOT_TAG', defaultValue: 'shot');

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  Future<void> shot(WidgetTester t, String name) async {
    await _settle(t);
    await binding.takeScreenshot('${_tag}_$name');
  }

  testWidgets('screenshots: auth + shell', (t) async {
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();
    final repo = FirebaseAuthRepository();
    await t.pumpWidget(DelivTrackApp(repository: repo));
    await _settle(t);
    await _settle(t);
    await shot(t, '01_login');

    await repo.signUp(
      name: 'Muhammad Afzaal',
      email: 'shots${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
      password: 'secret123',
    );
    await shot(t, '02_dashboard');

    await t.tap(find.text('More').last);
    await shot(t, '03_more');

    await t.tap(find.text('Log out').first);
    await shot(t, '04_logout_dialog');
    await t.tap(find.text('Cancel'));
    await _settle(t);
  });
}
