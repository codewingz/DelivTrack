import 'dart:async';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/features/auth/views/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_auth_repository.dart';

Future<void> _pump(WidgetTester t, FakeAuthRepository repo,
    {Size size = const Size(393, 852), double scale = 1, VoidCallback? onBack}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: ForgotPasswordScreen(repository: repo, onBackToLogin: onBack ?? () {}),
  ));
}

Finder get _send => find.byType(FilledButton);

void main() {
  group('ForgotPasswordScreen (real user flows)', () {
    testWidgets('empty email is blocked', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await t.tap(_send);
      await t.pump();
      expect(find.text('Email address is required'), findsOneWidget);
      expect(repo.resets, isEmpty);
    });

    testWidgets('invalid email is blocked', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await t.enterText(find.byType(TextFormField), 'nope');
      await t.tap(_send);
      await t.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repo.resets, isEmpty);
    });

    testWidgets('valid email sends once (trimmed) and shows neutral confirmation', (t) async {
      final repo = FakeAuthRepository();
      await _pump(t, repo);
      await t.enterText(find.byType(TextFormField), '  owner@codewingz.com ');
      await t.tap(_send);
      await t.pump();
      await t.pump();
      expect(repo.resets, ['owner@codewingz.com']);
      expect(find.textContaining('If an account exists for owner@codewingz.com'), findsOneWidget);
      expect(find.text('Resend Link'), findsOneWidget);
    });

    testWidgets('failure shows error and no confirmation', (t) async {
      final repo = FakeAuthRepository(failure: AppFailure(authErrorMessage('network-request-failed')));
      await _pump(t, repo);
      await t.enterText(find.byType(TextFormField), 'owner@codewingz.com');
      await t.tap(_send);
      await t.pump();
      await t.pump();
      expect(find.textContaining('No internet'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsNothing);
    });

    testWidgets('confirmation is cleared when sending again', (t) async {
      final repo = FakeAuthRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await t.enterText(find.byType(TextFormField), 'owner@codewingz.com');
      await t.tap(_send);
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsNothing);
      repo.gate!.complete();
      await t.pump();
      await t.pump();
      expect(find.textContaining('If an account exists'), findsOneWidget);
    });

    testWidgets('repeated taps while loading send only once', (t) async {
      final repo = FakeAuthRepository()..gate = Completer<void>();
      await _pump(t, repo);
      await t.enterText(find.byType(TextFormField), 'owner@codewingz.com');
      await t.tap(_send);
      await t.pump();
      await t.tap(_send, warnIfMissed: false);
      await t.pump();
      expect(repo.resets, hasLength(1));
      repo.gate!.complete();
      await t.pump();
      await t.pump();
    });

    testWidgets('"Back to log in" calls onBackToLogin', (t) async {
      var tapped = false;
      await _pump(t, FakeAuthRepository(), onBack: () => tapped = true);
      await t.ensureVisible(find.text('Back to log in'));
      await t.tap(find.text('Back to log in'));
      expect(tapped, isTrue);
    });
  });

  group('ForgotPasswordScreen responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('no overflow at $size text x$scale (confirmation shown)', (t) async {
          await _pump(t, FakeAuthRepository(), size: size, scale: scale);
          await t.enterText(find.byType(TextFormField), 'owner@codewingz.com');
          await t.ensureVisible(_send);
          await t.tap(_send);
          await t.pump();
          await t.pump();
          expect(t.takeException(), isNull);
          expect(find.textContaining('If an account exists'), findsOneWidget);
        });
      }
    }
  });
}
