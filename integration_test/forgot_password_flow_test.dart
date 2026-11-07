// Real-user forgot-password flow against the Firebase Auth *emulator* (no real accounts/emails).
// The emulator does not send email; the reset code is read from its REST API instead.
// Run: firebase emulators:start --only auth --project delivtrack-codewingz
//      flutter test integration_test/forgot_password_flow_test.dart -d <android-emulator>
import 'dart:convert';
import 'dart:io';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/auth/views/forgot_password_screen.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _emulatorHost = '10.0.2.2'; // host machine as seen from the Android emulator

Future<String?> _latestResetCode(String email) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://$_emulatorHost:9099/emulator/v1/projects/delivtrack-codewingz/oobCodes'),
    );
    final body = await (await request.close()).transform(utf8.decoder).join();
    final codes = (jsonDecode(body)['oobCodes'] as List).cast<Map<String, dynamic>>();
    final mine = codes.where((c) => c['email'] == email && c['requestType'] == 'PASSWORD_RESET');
    return mine.isEmpty ? null : mine.last['oobCode'] as String;
  } finally {
    client.close();
  }
}

Future<void> _sendReset(WidgetTester t, String email) async {
  await t.enterText(find.byType(TextFormField), email);
  await t.tap(find.byType(FilledButton));
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

  Future<void> pumpScreen(WidgetTester t) => t.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(repository: FirebaseAuthRepository(), onBackToLogin: () {}),
        ),
      );

  testWidgets('owner requests reset, sets a new password, old one stops working', (t) async {
    final email = 'reset${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await FirebaseAuthRepository().signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');
    await FirebaseAuth.instance.signOut();

    await pumpScreen(t);
    await _sendReset(t, email);
    expect(find.textContaining('If an account exists for $email'), findsOneWidget);

    final code = await _latestResetCode(email);
    expect(code, isNotNull, reason: 'Firebase must have issued a PASSWORD_RESET code');
    await FirebaseAuth.instance.confirmPasswordReset(code: code!, newPassword: 'newSecret456');

    await expectLater(
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: 'secret123'),
      throwsA(isA<FirebaseAuthException>()),
    );
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: 'newSecret456');
    expect(cred.user?.email, email);
  });

  testWidgets('unregistered email gets the same neutral confirmation (no account enumeration)', (t) async {
    await pumpScreen(t);
    final ghost = 'ghost${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await _sendReset(t, ghost);

    expect(find.textContaining('If an account exists for $ghost'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(await _latestResetCode(ghost), isNull, reason: 'no code should be issued for an unknown email');
  });

  testWidgets('email with capitals and spaces still resets the right account', (t) async {
    final email = 'case${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await FirebaseAuthRepository().signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');
    await FirebaseAuth.instance.signOut();

    await pumpScreen(t);
    await _sendReset(t, '  ${email.toUpperCase()}  ');

    expect(await _latestResetCode(email), isNotNull);
  });

  testWidgets('resend issues a fresh code', (t) async {
    final email = 'resend${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await FirebaseAuthRepository().signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');
    await FirebaseAuth.instance.signOut();

    await pumpScreen(t);
    await _sendReset(t, email);
    final first = await _latestResetCode(email);
    await t.tap(find.text('Resend Link'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty && i > 2) break;
    }
    final second = await _latestResetCode(email);
    expect(second, isNotNull);
    expect(second, isNot(first));
  });
}
