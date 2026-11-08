import 'dart:async';

import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/auth/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';

Future<void> _pump(
  WidgetTester t,
  FakeAuthRepository repo, {
  Size size = const Size(393, 852),
  double scale = 1,
  VoidCallback? onSignUp,
  VoidCallback? onForgot,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: LoginScreen(
        repository: repo,
        onSignUp: onSignUp ?? () {},
        onForgotPassword: onForgot ?? () {},
      ),
    ),
  );
}

Future<void> _fill(
  WidgetTester t, {
  String email = 'owner@codewingz.com',
  String pw = 'secret123',
}) async {
  final fields = find.byType(TextFormField);
  await t.enterText(fields.at(0), email);
  await t.enterText(fields.at(1), pw);
}

Finder get _logIn => find.widgetWithText(FilledButton, 'Log In');

void main() {
  group('LoginScreen (real user flows)', () {
    testWidgets(
      'empty submit shows field errors and does not call repository',
      (t) async {
        final repo = FakeAuthRepository();
        await _pump(t, repo);
        await t.tap(_logIn);
        await t.pump();
        expect(find.text('Email address is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);
        expect(repo.signIns, isEmpty);
      },
    );

    testWidgets('invalid email is blocked', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t, email: 'nope');
      await t.tap(_logIn);
      await t.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repo.signIns, isEmpty);
    });

    testWidgets('short password is NOT rejected locally (server decides)', (
      t,
    ) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t, pw: '123');
      await t.tap(_logIn);
      await t.pump();
      await t.pump();
      expect(repo.signIns, hasLength(1));
    });

    testWidgets('valid submit signs in once with the entered values', (
      t,
    ) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await _fill(t);
      await t.tap(_logIn);
      await t.pump();
      await t.pump();
      expect(repo.signIns.single, (
        email: 'owner@codewingz.com',
        password: 'secret123',
      ));
    });

    testWidgets(
      'wrong credentials show one generic message and keep the form',
      (t) async {
        final repo = FakeAuthRepository(
          failure: AppFailure(authErrorMessage('invalid-credential')),
        );
        await _pump(t, repo);
        await _fill(t);
        await t.tap(_logIn);
        await t.pump();
        await t.pump();
        expect(find.text('Incorrect email or password.'), findsOneWidget);
        expect(find.text('owner@codewingz.com'), findsOneWidget);
      },
    );

    testWidgets('repeated taps while loading sign in only once', (t) async {
      final repo = FakeAuthRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await _fill(t);
      await t.tap(_logIn);
      await t.pump();
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      await t.pump();
      expect(repo.signIns, hasLength(1));
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      repo.gate!.complete();
      await t.pump();
      await t.pump();
    });

    testWidgets('"Forgot password?" link calls onForgotPassword', (t) async {
      var tapped = false;
      await _pump(t, FakeAuthRepository(), onForgot: () => tapped = true);
      await t.tap(find.text('Forgot password?'));
      expect(tapped, isTrue);
    });

    testWidgets('"Sign up" link calls onSignUp', (t) async {
      var tapped = false;
      await _pump(t, FakeAuthRepository(), onSignUp: () => tapped = true);
      await t.ensureVisible(find.text('Sign up'));
      await t.tap(find.text('Sign up'));
      expect(tapped, isTrue);
    });
  });

  group('LoginScreen responsive', () {
    const sizes = [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(640, 300),
    ];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale (with error shown)', (
          t,
        ) async {
          await _pump(
            t,
            FakeAuthRepository(
              failure: const AppFailure('Incorrect email or password.'),
            ),
            size: size,
            scale: scale,
          );
          await _fill(t);
          await t.tap(_logIn, warnIfMissed: false);
          await t.pump();
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
