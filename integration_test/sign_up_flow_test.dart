// Real-user sign-up flow against the Firebase Auth *emulator* (no real accounts created).
// Run: firebase emulators:start --only auth --project delivtrack-codewingz
//      adb reverse tcp:9099 tcp:9099
//      flutter test integration_test/sign_up_flow_test.dart -d <android-device>
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/auth/views/sign_up_screen.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _signUp(WidgetTester t, String email, String password, {String? confirm, String name = 'Muhammad Afzaal'}) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), name);
  await t.enterText(fields.at(1), email);
  await t.enterText(fields.at(2), password);
  await t.enterText(fields.at(3), confirm ?? password);
  await t.tap(find.widgetWithText(FilledButton, 'Sign Up'));
  // Wait for the request to finish (spinner gone) without outliving the 4s snackbar.
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty && i > 2) break;
  }
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  setUp(() => FirebaseAuth.instance.signOut());

  Future<void> pumpScreen(WidgetTester t) => t.pumpWidget(
        MaterialApp(home: SignUpScreen(repository: FirebaseAuthRepository(), onLogIn: () {})),
      );

  testWidgets('new owner signs up, is signed in, and can log in again', (t) async {
    final email = 'owner${DateTime.now().millisecondsSinceEpoch}@codewingz.com';
    await pumpScreen(t);
    await _signUp(t, email, 'secret123', name: '  Muhammad Afzaal  ');

    expect(find.text('Account created successfully.'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser?.email, email);
    expect(FirebaseAuth.instance.currentUser?.displayName, 'Muhammad Afzaal');

    await FirebaseAuth.instance.signOut();
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: 'secret123');
    expect(cred.user?.email, email);
    expect(cred.user?.displayName, 'Muhammad Afzaal', reason: 'name must persist on the server, not just locally');
  });

  testWidgets('same email twice shows already-registered message', (t) async {
    final email = 'dup${DateTime.now().millisecondsSinceEpoch}@codewingz.com';
    await pumpScreen(t);
    await _signUp(t, email, 'secret123');
    await FirebaseAuth.instance.signOut();

    await pumpScreen(t);
    await _signUp(t, email, 'secret123');
    expect(find.textContaining('already registered'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  testWidgets('email with different letter case is still treated as the same account', (t) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await pumpScreen(t);
    await _signUp(t, 'case$stamp@codewingz.com', 'secret123');
    await FirebaseAuth.instance.signOut();

    await pumpScreen(t);
    await _signUp(t, 'CASE$stamp@codewingz.com', 'secret123');
    expect(find.textContaining('already registered'), findsOneWidget);
  });

  testWidgets('mismatched passwords never reach Firebase', (t) async {
    await pumpScreen(t);
    await _signUp(t, 'mismatch${DateTime.now().millisecondsSinceEpoch}@codewingz.com', 'secret123', confirm: 'secret124');
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}
