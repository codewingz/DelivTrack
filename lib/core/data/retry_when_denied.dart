import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/firestore_failure.dart';

/// Two writes at the same moment both read the same document. The mobile SDK commits with an "unchanged
/// since read" precondition, but Firestore checks the rules first, so the loser is answered
/// "permission-denied" (not the retryable "aborted"). Verified against the real backend (5 parallel
/// saves: one wins per round, all succeed within 5 attempts).
///
/// So [attempt] (a transaction that reads fresh state each time) is run again after a short, growing and
/// jittered pause, up to [maxAttempts] times. Only `permission-denied` is retried: a network failure or any
/// other Firestore error is reported at once, and an app-level refusal ([AppFailure] thrown inside the
/// transaction because the freshly read state no longer allows the action) is not a [FirebaseException],
/// so it passes straight through. A genuine rule denial fails the same way every time and is reported
/// after the last attempt.
Future<T> retryWhenDenied<T>(
  Future<T> Function() attempt, {
  int maxAttempts = 5,
  Future<void> Function(Duration pause)? wait,
  Random? random,
}) async {
  final jitter = random ?? Random();
  final pause = wait ?? (Duration d) => Future<void>.delayed(d);
  for (var tries = 1; ; tries++) {
    try {
      return await attempt();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' || tries >= maxAttempts) {
        throw firestoreFailure(e);
      }
      await pause(Duration(milliseconds: 25 * tries + jitter.nextInt(75)));
    }
  }
}
