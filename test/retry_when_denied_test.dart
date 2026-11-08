import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/data/retry_when_denied.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _firestore(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  late List<Duration> pauses;
  Future<void> wait(Duration d) async => pauses.add(d);
  setUp(() => pauses = []);

  Future<T> run<T>(Future<T> Function() attempt) =>
      retryWhenDenied(attempt, wait: wait, random: Random(1));

  test('success on the first try: one attempt, no pause', () async {
    var calls = 0;
    expect(await run(() async => ++calls), 1);
    expect(pauses, isEmpty);
  });

  test('concurrent contention (denied, denied, then success): retried with growing pauses', () async {
    var calls = 0;
    final result = await run(() async {
      if (++calls < 3) throw _firestore('permission-denied');
      return 'saved';
    });
    expect(result, 'saved');
    expect(calls, 3);
    expect(pauses, hasLength(2));
    expect(pauses[0].inMilliseconds, inInclusiveRange(25, 99));
    expect(pauses[1].inMilliseconds, inInclusiveRange(50, 124));
  });

  test('a genuine denial is retried a bounded number of times, then reported as a clear failure', () async {
    var calls = 0;
    await expectLater(
      run(() async {
        calls++;
        throw _firestore('permission-denied');
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'You are not allowed to do that. Please log in again.',
        ),
      ),
    );
    expect(calls, 5, reason: 'five attempts, no more');
    expect(pauses, hasLength(4), reason: 'no pause after the last attempt');
    expect(
      pauses.fold<int>(0, (total, d) => total + d.inMilliseconds),
      lessThan(1200),
      reason: 'a genuine denial is reported within about a second',
    );
  });

  test(
    'other Firestore errors are not retried (network, unavailable, unknown)',
    () async {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
      ]) {
        var calls = 0;
        await expectLater(
          run(() async {
            calls++;
            throw _firestore(code);
          }),
          throwsA(isA<AppFailure>()),
          reason: code,
        );
        expect(calls, 1, reason: code);
      }
      expect(pauses, isEmpty);
    },
  );

  test('an app-level refusal (archived parcel, overpayment…) passes straight through without a retry', () async {
    var calls = 0;
    await expectLater(
      run(() async {
        calls++;
        throw const AppFailure('This parcel is archived. Restore it first.');
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'This parcel is archived. Restore it first.',
        ),
      ),
    );
    expect(calls, 1);
    expect(pauses, isEmpty);
  });

  test('a denial that clears because the fresh read now refuses the action ends with that refusal, not the denial', () async {
    var calls = 0;
    await expectLater(
      run(() async {
        if (++calls == 1) throw _firestore('permission-denied');
        throw const AppFailure('The data changed: nothing is outstanding.');
      }),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'The data changed: nothing is outstanding.',
        ),
      ),
    );
    expect(calls, 2);
  });

  test('the number of attempts is configurable', () async {
    var calls = 0;
    await expectLater(
      retryWhenDenied(
        () async {
          calls++;
          throw _firestore('permission-denied');
        },
        maxAttempts: 2,
        wait: wait,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(calls, 2);
  });
}
