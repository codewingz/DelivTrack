import 'package:deliv_track/features/settings/domain/sender_profile.dart';
import 'package:deliv_track/features/settings/views/sender_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_sender_profile_repository.dart';

Widget _wrap(Widget child, {Size size = const Size(393, 852), double scale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    ),
  );
}

Finder get _name => find.byType(TextFormField).at(0);
Finder get _phone => find.byType(TextFormField).at(1);
Finder get _address => find.byType(TextFormField).at(2);

void main() {
  group('SenderProfileScreen', () {
    testWidgets('loads and populates existing sender profile', (t) async {
      final repo = FakeSenderProfileRepository(
        initial: const SenderProfile(
          name: 'Ali Collection',
          phone: '0300 1234567',
          address: 'Shop 12, Main Bazaar, Lahore',
        ),
      );

      await t.pumpWidget(_wrap(SenderProfileScreen(repository: repo)));
      await t.pumpAndSettle();

      expect((t.widget(_name) as TextFormField).controller?.text, 'Ali Collection');
      expect((t.widget(_phone) as TextFormField).controller?.text, '0300 1234567');
      expect((t.widget(_address) as TextFormField).controller?.text, 'Shop 12, Main Bazaar, Lahore');
    });

    testWidgets('validation prevents saving empty or invalid fields', (t) async {
      final repo = FakeSenderProfileRepository();

      await t.pumpWidget(_wrap(SenderProfileScreen(repository: repo)));
      await t.pumpAndSettle();

      await t.tap(find.text('Save details'));
      await t.pumpAndSettle();

      expect(find.text('Sender / Business name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Return address is required'), findsOneWidget);
      expect(repo.saveCount, 0);

      // Invalid short values
      await t.enterText(_name, 'A');
      await t.enterText(_phone, '123');
      await t.enterText(_address, 'abc');
      await t.tap(find.text('Save details'));
      await t.pumpAndSettle();

      expect(find.text('Use 2–60 characters'), findsOneWidget);
      expect(find.text('Enter a valid phone number'), findsOneWidget);
      expect(find.text('Enter the full address (5–200 characters)'), findsOneWidget);
      expect(repo.saveCount, 0);
    });

    testWidgets('valid input saves profile and shows snackbar', (t) async {
      final repo = FakeSenderProfileRepository();

      await t.pumpWidget(_wrap(SenderProfileScreen(repository: repo)));
      await t.pumpAndSettle();

      await t.enterText(_name, 'Zara Collections');
      await t.enterText(_phone, '0321 9876543');
      await t.enterText(_address, 'Plot 45, Sector F, Islamabad');

      await t.tap(find.text('Save details'));
      await t.pumpAndSettle();

      expect(repo.saveCount, 1);
      final saved = await repo.getProfile();
      expect(saved?.name, 'Zara Collections');
      expect(saved?.phone, '0321 9876543');
      expect(saved?.address, 'Plot 45, Sector F, Islamabad');
      expect(find.text('Sender details saved.'), findsOneWidget);
    });

    for (final size in [
      const Size(320, 568),
      const Size(393, 852),
      const Size(700, 900),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('responsive layout at $size text x$scale does not overflow', (t) async {
          final repo = FakeSenderProfileRepository(
            initial: const SenderProfile(
              name: 'Ali Collection',
              phone: '0300 1234567',
              address: 'Shop 12, Main Bazaar, Lahore',
            ),
          );

          await t.pumpWidget(_wrap(SenderProfileScreen(repository: repo), size: size, scale: scale));
          await t.pumpAndSettle();

          expect(find.byType(SenderProfileScreen), findsOneWidget);
          expect(find.byType(ListView), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });
}
