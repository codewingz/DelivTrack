import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/errors/firestore_failure.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _error(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('firestoreFailure: what the user is told', () {
    test('offline or slow network', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          firestoreFailure(_error(code)).message,
          'No internet connection. Check your network and try again.',
          reason: code,
        );
      }
    });

    test('permission denied or signed out', () {
      for (final code in ['permission-denied', 'unauthenticated']) {
        expect(
          firestoreFailure(_error(code)).message,
          'You are not allowed to do that. Please log in again.',
          reason: code,
        );
      }
    });

    test('contention and anything unknown', () {
      expect(
        firestoreFailure(_error('aborted')).message,
        'The data changed while saving. Please try again.',
      );
      expect(
        firestoreFailure(_error('internal')).message,
        'Something went wrong. Please try again.',
      );
    });
  });

  test('stream errors from Firestore become user-presentable failures; other errors pass through', () async {
    final errors = <Object>[];
    final stream = Stream<int>.multi((c) {
      c.addError(_error('unavailable'));
      c.addError(StateError('programming error'));
      c.close();
    }).withFirestoreFailures();
    await stream.handleError(errors.add).drain<void>();
    expect(errors.first, isA<AppFailure>());
    expect(
      (errors.first as AppFailure).message,
      startsWith('No internet connection'),
    );
    expect(
      errors.last,
      isA<StateError>(),
      reason: 'bugs are not disguised as network problems',
    );
  });
}
