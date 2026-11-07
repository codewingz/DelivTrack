// Full-app session flow (real router + real firebase_auth) against the Auth *emulator*.
// Run: firebase emulators:start --only auth --project delivtrack-codewingz
//      flutter test integration_test/session_flow_test.dart -d <android-emulator>
import 'dart:convert';
import 'dart:io';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:deliv_track/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

const _emulatorHost = '10.0.2.2';

Finder get _onLogin => find.text('Welcome back');
Finder get _onDashboard => find.byIcon(Icons.logout_rounded);

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

Future<void> _fillAndSubmit(WidgetTester t, List<String> values, String buttonLabel) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < values.length; i++) {
    await t.tap(fields.at(i));
    await t.pump(const Duration(milliseconds: 200));
    await t.enterText(fields.at(i), values[i]);
  }
  final button = find.widgetWithText(FilledButton, buttonLabel);
  await t.ensureVisible(button);
  await t.pump();
  await t.tap(button);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  setUp(() => FirebaseAuth.instance.signOut());

  Future<void> openApp(WidgetTester t) async {
    await t.pumpWidget(DelivTrackApp(repository: FirebaseAuthRepository(), productRepository: FirestoreProductRepository(), customerRepository: FirestoreCustomerRepository()));
  }

  testWidgets('sign up -> dashboard with name; reopening app stays on dashboard; logout -> login; login -> dashboard',
      (t) async {
    final email = 'session${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    await openApp(t);
    await pumpUntil(t, _onLogin);

    // Sign up through the UI.
    await t.tap(find.text('Sign up'));
    await pumpUntil(t, find.text('Create account'));
    await _fillAndSubmit(t, ['Muhammad Afzaal', email, 'secret123', 'secret123'], 'Sign Up');
    await pumpUntil(t, _onDashboard);
    await pumpUntil(t, find.text('Welcome, Muhammad Afzaal'));
    expect(_onLogin, findsNothing);

    // "Close and reopen the app": a brand-new app instance with the saved session.
    await t.pumpWidget(const SizedBox());
    await openApp(t);
    await pumpUntil(t, _onDashboard);
    expect(_onLogin, findsNothing, reason: 'saved user must never see login again');
    expect(find.text('Welcome, Muhammad Afzaal'), findsOneWidget);

    // Log out.
    await t.tap(_onDashboard);
    await pumpUntil(t, find.text('Log out?'));
    await t.tap(find.widgetWithText(TextButton, 'Log out'));
    await pumpUntil(t, _onLogin);
    expect(FirebaseAuth.instance.currentUser, isNull);

    // Log in again.
    await _fillAndSubmit(t, [email, 'secret123'], 'Log In');
    await pumpUntil(t, _onDashboard);
    expect(find.text('Welcome, Muhammad Afzaal'), findsOneWidget);
  });

  testWidgets('password reset elsewhere signs this device out and shows login', (t) async {
    final email = 'revoke${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    final repo = FirebaseAuthRepository();
    await repo.signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');

    await t.pumpWidget(DelivTrackApp(repository: repo, productRepository: FirestoreProductRepository(), customerRepository: FirestoreCustomerRepository()));
    await pumpUntil(t, _onDashboard);

    // Someone resets the password from another device.
    await repo.sendPasswordReset(email: email);
    final code = await _latestResetCode(email);
    expect(code, isNotNull);
    await FirebaseAuth.instance.confirmPasswordReset(code: code!, newPassword: 'newSecret456');

    // App checks the session (this also runs at launch and on resume).
    await repo.verifySession();
    await pumpUntil(t, _onLogin);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  testWidgets('offline-style errors do not log the user out', (t) async {
    final email = 'keep${DateTime.now().microsecondsSinceEpoch}@codewingz.com';
    final repo = FirebaseAuthRepository();
    await repo.signUp(name: 'Muhammad Afzaal', email: email, password: 'secret123');
    await t.pumpWidget(DelivTrackApp(repository: repo, productRepository: FirestoreProductRepository(), customerRepository: FirestoreCustomerRepository()));
    await pumpUntil(t, _onDashboard);

    await repo.verifySession(); // valid session: must stay signed in
    await t.pump(const Duration(milliseconds: 500));
    expect(_onDashboard, findsOneWidget);
    expect(FirebaseAuth.instance.currentUser?.email, email);
  });
}
