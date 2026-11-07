import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

Future<void> _launch(WidgetTester t, FakeAuthRepository repo, {Size size = const Size(393, 852), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(DelivTrackApp(repository: repo, productRepository: FakeProductRepository(), customerRepository: FakeCustomerRepository(), parcelRepository: FakeParcelRepository()));
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
}

Finder get _homeTab => find.descendant(of: find.byType(NavigationBar), matching: find.text('Home'));
Finder get _moreTab => find.descendant(of: find.byType(NavigationBar), matching: find.text('More'));

void main() {
  group('bottom navigation shell', () {
    testWidgets('signed-in user sees Home and More tabs; More opens and Home returns', (t) async {
      await _launch(t, FakeAuthRepository(signedIn: true, name: 'Ali'));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Welcome, Ali'), findsOneWidget);

      await t.tap(_moreTab);
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Log out'), findsOneWidget);

      await t.tap(_homeTab);
      await t.pumpAndSettle();
      expect(find.text('Welcome, Ali'), findsOneWidget);
    });

    testWidgets('signed-out screens have no bottom bar', (t) async {
      await _launch(t, FakeAuthRepository());
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('products entry', () {
    testWidgets('More lists Products; it opens the screen and back returns to More', (t) async {
      await _launch(t, FakeAuthRepository(signedIn: true, name: 'Ali'));
      await t.tap(_moreTab);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Products'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Products'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'pushed full screen hides the tabs');

      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Products'), findsOneWidget);
    });
  });

  group('log out confirmation', () {
    testWidgets('More: Cancel keeps the session, Confirm signs out and shows login', (t) async {
      final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
      await _launch(t, repo);
      await t.tap(_moreTab);
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(ListTile, 'Log out'));
      await t.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(repo.signOuts, 0);
      expect(repo.isSignedIn, isTrue);
      expect(find.widgetWithText(ListTile, 'Log out'), findsOneWidget);

      await t.tap(find.widgetWithText(ListTile, 'Log out'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Log out'));
      await t.pumpAndSettle();
      expect(repo.signOuts, 1);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Dashboard icon: Cancel keeps the session', (t) async {
      final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
      await _launch(t, repo);
      await t.tap(find.byIcon(Icons.logout_rounded));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(repo.signOuts, 0);
      expect(find.text('Welcome, Ali'), findsOneWidget);
    });

    testWidgets('tapping outside the dialog dismisses it without logging out', (t) async {
      final repo = FakeAuthRepository(signedIn: true, name: 'Ali');
      await _launch(t, repo);
      await t.tap(find.byIcon(Icons.logout_rounded));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      expect(find.text('Log out?'), findsNothing);
      expect(repo.signOuts, 0);
    });
  });

  group('shell responsive', () {
    const sizes = [Size(320, 568), Size(393, 852), Size(700, 900), Size(1100, 800), Size(640, 300)];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('Home, More and the dialog do not overflow at $size text x$scale', (t) async {
          await _launch(t, FakeAuthRepository(signedIn: true, name: 'Muhammad Afzaal Khan'), size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.tap(_moreTab);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.tap(find.widgetWithText(ListTile, 'Log out'));
          await t.pumpAndSettle();
          expect(find.text('Log out?'), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
