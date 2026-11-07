import 'dart:async';
import 'helpers/fake_auth_repository.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/core/view_models/action_view_model.dart';
import 'package:deliv_track/features/auth/views/sign_up_screen.dart';
import 'package:deliv_track/utils/app_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _fill(WidgetTester t, {String name = 'Muhammad Afzaal', String email = 'owner@codewingz.com', String pw = 'secret123', String? confirm}) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), name);
  await t.enterText(fields.at(1), email);
  await t.enterText(fields.at(2), pw);
  await t.enterText(fields.at(3), confirm ?? pw);
}

Future<void> _pump(WidgetTester t, AuthRepository repo, {Size size = const Size(393, 852), double scale = 1, VoidCallback? onLogIn}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: SignUpScreen(repository: repo, onLogIn: onLogIn ?? () {}),
  ));
}

Finder get _signUpButton => find.widgetWithText(FilledButton, 'Sign Up');

void main() {
  group('authErrorMessage', () {
    test('maps known Firebase codes and falls back', () {
      expect(authErrorMessage('email-already-in-use'), contains('already registered'));
      expect(authErrorMessage('weak-password'), contains('6 characters'));
      expect(authErrorMessage('network-request-failed'), contains('internet'));
      expect(authErrorMessage('invalid-email'), contains('valid email'));
      expect(authErrorMessage('invalid-credential'), 'Incorrect email or password.');
      expect(authErrorMessage('user-not-found'), 'Incorrect email or password.');
      expect(authErrorMessage('user-disabled'), contains('disabled'));
      expect(authErrorMessage('something-new'), contains('Something went wrong'));
    });
  });

  group('AppValidators.confirmPassword', () {
    test('empty / mismatch / match', () {
      expect(AppValidators.confirmPassword('', 'abc123'), 'Please confirm your password');
      expect(AppValidators.confirmPassword('abc124', 'abc123'), 'Passwords do not match');
      expect(AppValidators.confirmPassword('abc123', 'abc123'), isNull);
    });
  });

  group('ActionViewModel', () {
    test('success clears error and returns true', () async {
      final vm = ActionViewModel();
      expect(await vm.run(() async {}), isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('failure exposes message and returns false', () async {
      final vm = ActionViewModel();
      expect(await vm.run(() async => throw const AppFailure('boom')), isFalse);
      expect(vm.errorMessage, 'boom');
    });

    test('a new run clears the previous error', () async {
      final vm = ActionViewModel();
      await vm.run(() async => throw const AppFailure('boom'));
      await vm.run(() async {});
      expect(vm.errorMessage, isNull);
    });

    test('second call while loading is ignored', () async {
      final gate = Completer<void>();
      var calls = 0;
      final vm = ActionViewModel();
      final first = vm.run(() async {
        calls++;
        await gate.future;
      });
      expect(await vm.run(() async => calls++), isFalse);
      gate.complete();
      expect(await first, isTrue);
      expect(calls, 1);
    });

    test('disposing while a request runs does not throw', () async {
      final gate = Completer<void>();
      final vm = ActionViewModel();
      final pending = vm.run(() => gate.future);
      vm.dispose();
      gate.complete();
      await pending;
    });
  });

  group('SignUpScreen (real user flows)', () {
    testWidgets('empty submit shows field errors and does not call repository', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await t.tap(_signUpButton);
      await t.pump();
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });

    testWidgets('whitespace-only name is blocked', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t, name: '   ');
      await t.tap(_signUpButton);
      await t.pump();
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });

    testWidgets('invalid email, short password and mismatch are blocked', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t, email: 'not-an-email', pw: '123', confirm: '1234');
      await t.tap(_signUpButton);
      await t.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });

    testWidgets('valid submit calls repository once with the entered values', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t);
      await t.tap(_signUpButton);
      await t.pump();
      await t.pump();
      expect(repo.signUps.single, (name: 'Muhammad Afzaal', email: 'owner@codewingz.com', password: 'secret123'));
    });

    testWidgets('repeated taps while loading create only one account', (t) async {
      final repo = FakeAuthRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await _fill(t);
      await t.tap(_signUpButton);
      await t.pump();
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      await t.pump();
      expect(repo.signUps, hasLength(1));
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await t.pump();
      await t.pump();
    });

    testWidgets('already-registered email shows server message and keeps form', (t) async {
      final repo = FakeAuthRepository(failure: const AppFailure('This email is already registered. Try logging in instead.'));
      await _pump(t, repo);
      await _fill(t);
      await t.tap(_signUpButton);
      await t.pump();
      await t.pump();
      expect(find.textContaining('already registered'), findsOneWidget);
      expect(find.text('owner@codewingz.com'), findsOneWidget);
    });
  });

  testWidgets('"Log in" link calls onLogIn', (t) async {
    var tapped = false;
    await _pump(t, FakeAuthRepository(), onLogIn: () => tapped = true);
    await t.ensureVisible(find.text('Log in'));
    await t.tap(find.text('Log in'));
    expect(tapped, isTrue);
  });

  group('SignUpScreen responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale (with errors shown)', (t) async {
          await _pump(t, FakeAuthRepository(failure: const AppFailure('Something went wrong. Please try again.')), size: size, scale: scale);
          await _fill(t, confirm: 'different');
          await t.tap(_signUpButton, warnIfMissed: false);
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
