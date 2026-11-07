// Real-user login flow against the Firebase Auth *emulator* (no real accounts created).
// Run: firebase emulators:start --only auth --project delivtrack-codewingz
//      flutter test integration_test/login_flow_test.dart -d <android-device>
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/auth/views/login_screen.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _logIn(WidgetTester t, String email, String password) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), email);
  await t.enterText(fields.at(1), password);
  await t.tap(find.widgetWithText(FilledButton, 'Log In'));
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

  Future<String> registerExistingUser() async {
    final email = 'login${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    final repo = FirebaseAuthRepository();
    await repo.signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');
    await FirebaseAuth.instance.signOut();
    return email;
  }

  Future<void> pumpScreen(WidgetTester t) => t.pumpWidget(
        MaterialApp(home: LoginScreen(repository: FirebaseAuthRepository(), onSignUp: () {})),
      );

  testWidgets('registered owner logs in with correct credentials', (t) async {
    final email = await registerExistingUser();
    await pumpScreen(t);
    await _logIn(t, email, 'secret123');

    expect(find.text('Logged in successfully.'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser?.email, email);
    expect(FirebaseAuth.instance.currentUser?.displayName, 'Muhammad Afzaal');
  });

  testWidgets('wrong password shows incorrect-credentials message and stays signed out', (t) async {
    final email = await registerExistingUser();
    await pumpScreen(t);
    await _logIn(t, email, 'wrong-password');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  testWidgets('unknown email shows the same message (no account enumeration)', (t) async {
    await pumpScreen(t);
    await _logIn(t, 'nobody${DateTime.now().microsecondsSinceEpoch}@codewingz.com', 'secret123');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  testWidgets('email typed with capitals and spaces still logs in', (t) async {
    final email = await registerExistingUser();
    await pumpScreen(t);
    await _logIn(t, '  ${email.toUpperCase()}  ', 'secret123');

    expect(find.text('Logged in successfully.'), findsOneWidget);
    expect(FirebaseAuth.instance.currentUser?.email, email);
  });

  testWidgets('correct password after a failed attempt succeeds and clears the error', (t) async {
    final email = await registerExistingUser();
    await pumpScreen(t);
    await _logIn(t, email, 'wrong-password');
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    // Fields were disabled while the failed request ran: focus the field like a user would.
    await t.tap(fields.at(1));
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(fields.at(1), 'secret123');
    expect(t.widget<EditableText>(find.byType(EditableText).at(1)).controller.text, 'secret123');
    final button = find.widgetWithText(FilledButton, 'Log In');
    await t.ensureVisible(button);
    await t.pump();
    await t.tap(button);
    await t.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty && i > 2) break;
    }
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('Incorrect email or password.'), findsNothing);
    expect(FirebaseAuth.instance.currentUser?.email, email);
  });
}
