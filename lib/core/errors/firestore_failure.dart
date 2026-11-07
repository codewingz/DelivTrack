import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'app_failure.dart';

AppFailure firestoreFailure(FirebaseException e) => AppFailure(switch (e.code) {
      'unavailable' || 'deadline-exceeded' => 'No internet connection. Check your network and try again.',
      'permission-denied' || 'unauthenticated' => 'You are not allowed to do that. Please log in again.',
      'aborted' => 'The data changed while saving. Please try again.',
      _ => 'Something went wrong. Please try again.',
    });

extension FirestoreStreamFailures<T> on Stream<T> {
  /// Turns Firestore errors on this stream into user-presentable [AppFailure]s.
  Stream<T> withFirestoreFailures() => transform(
        StreamTransformer<T, T>.fromHandlers(
          handleError: (error, stackTrace, sink) =>
              sink.addError(error is FirebaseException ? firestoreFailure(error) : error, stackTrace),
        ),
      );
}
