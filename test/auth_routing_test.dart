import 'package:deliv_track/main.dart';
import 'package:deliv_track/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers/fake_auth_repository.dart';

Future<void> _launch(WidgetTester t, FakeAuthRepository repo) async {
  await t.pumpWidget(DelivTrackApp(repository: repo));
  await t.pump(const Duration(milliseconds: 2000)); // splash animation
  await t.pump();
  await t.pump();
}

Finder get _onLogin => find.text('Welcome back');
Finder get _onDashboard => find.byIcon(Icons.logout_rounded);

void main() {
  testWidgets('signed-out user lands on login', (t) async {
    await _launch(t, FakeAuthRepository());
    expect(_onLogin, findsOneWidget);
    expect(_onDashboard, findsNothing);
  });

  testWidgets('saved (signed-in) user opens straight on the dashboard, never login', (t) async {
    final repo = FakeAuthRepository(signedIn: true, name: 'Muhammad Afzaal');
    await _launch(t, repo);
    expect(_onDashboard, findsOneWidget);
    expect(find.text('Welcome, Muhammad Afzaal'), findsOneWidget);
    expect(_onLogin, findsNothing);
  });

  testWidgets('logging in from the login screen goes to the dashboard', (t) async {
    final repo = FakeAuthRepository();
    await _launch(t, repo);
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'owner@codewingz.com');
    await t.enterText(fields.at(1), 'secret123');
    await t.tap(find.widgetWithText(FilledButton, 'Log In'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(_onDashboard, findsOneWidget);
    expect(_onLogin, findsNothing);
  });

  testWidgets('signing up goes to the dashboard and shows the name even if it arrives late', (t) async {
    final repo = FakeAuthRepository();
    await _launch(t, repo);
    await t.ensureVisible(find.text('Sign up'));
    await t.tap(find.text('Sign up'));
    await t.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Muhammad Afzaal');
    await t.enterText(fields.at(1), 'owner@codewingz.com');
    await t.enterText(fields.at(2), 'secret123');
    await t.enterText(fields.at(3), 'secret123');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Sign Up'));
    await t.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(_onDashboard, findsOneWidget);
    expect(find.text('Welcome, Muhammad Afzaal'), findsOneWidget);
  });

  testWidgets('dashboard greeting updates when the name arrives after sign-in', (t) async {
    final repo = FakeAuthRepository(signedIn: true);
    await _launch(t, repo);
    expect(find.text('Welcome'), findsOneWidget);
    repo.emitName('Ali Khan');
    await t.pump();
    await t.pump();
    expect(find.text('Welcome, Ali Khan'), findsOneWidget);
  });

  testWidgets('log out returns to login and the dashboard cannot be reached again', (t) async {
    final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
    await _launch(t, repo);
    await t.tap(_onDashboard);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(repo.signOuts, 1);
    expect(_onLogin, findsOneWidget);
    expect(_onDashboard, findsNothing);
  });

  testWidgets('session revoked remotely (password reset elsewhere) sends the user to login', (t) async {
    final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
    await _launch(t, repo);
    expect(_onDashboard, findsOneWidget);
    repo.emitSignedIn(false);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(_onLogin, findsOneWidget);
  });

  testWidgets('signed-in user cannot open login/signup/forgot-password; is bounced to dashboard', (t) async {
    final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
    await _launch(t, repo);
    final router = GoRouter.of(t.element(find.byType(Scaffold).first));
    for (final path in [AppRoutes.login, AppRoutes.signUp, AppRoutes.forgotPassword]) {
      router.go(path);
      await t.pumpAndSettle();
      expect(_onDashboard, findsOneWidget, reason: path);
    }
  });

  testWidgets('signed-out user cannot open the dashboard by route', (t) async {
    await _launch(t, FakeAuthRepository());
    GoRouter.of(t.element(find.byType(Scaffold).first)).go(AppRoutes.home);
    await t.pumpAndSettle();
    expect(_onLogin, findsOneWidget);
    expect(_onDashboard, findsNothing);
  });

  testWidgets('session is verified at launch', (t) async {
    final repo = FakeAuthRepository(signedIn: true);
    await _launch(t, repo);
    expect(repo.verifyCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('session is re-verified when the app returns to the foreground', (t) async {
    final repo = FakeAuthRepository(signedIn: true);
    await _launch(t, repo);
    final before = repo.verifyCalls;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(repo.verifyCalls, before + 1);
  });
}
