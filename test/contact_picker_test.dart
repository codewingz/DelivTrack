import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/data/contact_picker.dart';
import 'package:deliv_track/utils/phone.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'cleanContactPhone: a number from the contacts, tidied for the phone field',
    () {
      test('Pakistan mobiles in any spelling become the local 03… form', () {
        for (final raw in [
          '+92 300 1234567',
          '+923001234567',
          '0092 300 1234567',
          '0092-300-1234567',
          '923001234567',
          '0300 1234567',
          '0300-1234567',
          '(0300) 123 4567',
          '03001234567',
          '  0300 123 45 67  ',
        ]) {
          expect(cleanContactPhone(raw), '03001234567', reason: raw);
        }
      });

      test('the result passes the form validator', () {
        for (final raw in [
          '+92 321 7654321',
          '0333-1112223',
          '0092 345 0000001',
        ]) {
          expect(isValidPhone(cleanContactPhone(raw)), isTrue, reason: raw);
        }
      });

      test('a landline or foreign number keeps its digits, spaces, dashes and leading +', () {
        expect(cleanContactPhone('+971 50 123 4567'), '+971 50 123 4567');
        expect(cleanContactPhone('+44 (20) 7946 0958'), '+44 20 7946 0958');
        expect(cleanContactPhone('042-35761234'), '042-35761234');
        expect(cleanContactPhone('  +1   650   555  0100 '), '+1 650 555 0100');
      });

      test('letters and symbols are dropped, and the length is capped at the field limit (20)', () {
        expect(
          cleanContactPhone('Home: +971-4-3334444 ext.'),
          '+971-4-3334444',
        );
        expect(
          cleanContactPhone('+971 50 123 4567 8901 2345 6789').length,
          lessThanOrEqualTo(20),
        );
        expect(cleanContactPhone(''), '');
        expect(cleanContactPhone('abc'), '');
      });
    },
  );

  group('SystemContactPicker (platform channel)', () {
    const channel = MethodChannel('flutter_native_contact_picker');
    final calls = <String>[];

    void answer(Object? Function() reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return reply();
          });
    }

    setUp(calls.clear);
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('asks for one phone number (not a whole contact) and returns the name and the chosen number', () async {
      answer(
        () => {
          'fullName': 'Sara Khan',
          'phoneNumbers': ['+92 300 1234567'],
          'selectedPhoneNumber': '+92 300 1234567',
        },
      );
      final picked = await const SystemContactPicker().pick();
      expect(calls, ['selectPhoneNumber']);
      expect(picked!.name, 'Sara Khan');
      expect(picked.phone, '+92 300 1234567');
    });

    test(
      'falls back to the first number when no selected number comes back',
      () async {
        answer(
          () => {
            'fullName': 'Sara Khan',
            'phoneNumbers': ['0300 1234567', '0321 7654321'],
          },
        );
        expect(
          (await const SystemContactPicker().pick())!.phone,
          '0300 1234567',
        );
      },
    );

    test(
      'backing out (null) or a contact without a number gives null',
      () async {
        answer(() => null);
        expect(await const SystemContactPicker().pick(), isNull);
        answer(
          () => {
            'fullName': 'No Number',
            'phoneNumbers': <String>[],
            'selectedPhoneNumber': '',
          },
        );
        expect(await const SystemContactPicker().pick(), isNull);
      },
    );

    test('a contact saved without a name still returns its number', () async {
      answer(
        () => {
          'phoneNumbers': ['03001234567'],
          'selectedPhoneNumber': '03001234567',
        },
      );
      final picked = await const SystemContactPicker().pick();
      expect(picked!.name, '');
      expect(picked.phone, '03001234567');
    });

    test('a platform error (no contacts app, picker could not start) becomes a plain message', () async {
      answer(
        () => throw PlatformException(
          code: 'intent_error',
          message: 'Could not launch contact picker',
        ),
      );
      await expectLater(
        const SystemContactPicker().pick(),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            "Couldn't open your contacts. Type the number instead.",
          ),
        ),
      );
    });
  });

  test('NoContactPicker offers nothing', () async {
    expect(await const NoContactPicker().pick(), isNull);
  });
}
