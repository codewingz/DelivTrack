import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/firestore_failure.dart';
import '../domain/app_settings.dart';

/// The signed-in owner's [AppSettings].
abstract class SettingsRepository {
  /// The latest settings known on this phone (the defaults until they load).
  /// Kept fresh by whoever listens to [watch]; Home always does.
  AppSettings get current;

  /// The settings, live. Emits the defaults while nothing is saved yet.
  Stream<AppSettings> watch();

  /// Throws [AppFailure] (e.g. no connection).
  Future<void> save(AppSettings settings);
}

/// Always the defaults; saving does nothing (previews and tests of screens
/// that only read the settings).
class NoSettingsRepository implements SettingsRepository {
  const NoSettingsRepository();

  @override
  AppSettings get current => const AppSettings();

  @override
  Stream<AppSettings> watch() => Stream.value(const AppSettings());

  @override
  Future<void> save(AppSettings settings) async {}
}

/// Keeps the settings in memory only (tests).
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this._current = const AppSettings()]);

  AppSettings _current;
  final _changes = StreamController<AppSettings>.broadcast();

  /// When set, [save] throws it.
  AppFailure? failure;

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (failure != null) throw failure!;
    _current = settings;
    _changes.add(settings);
  }
}

/// Stored at `users/{uid}/settings/app`; Firestore rules allow only that user.
class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // What was last read, and for whom: one owner's settings must never be
  // used for the next owner who signs in on this phone.
  AppSettings _cached = const AppSettings();
  String? _cachedUid;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('settings').doc('app');

  @override
  AppSettings get current {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid == _cachedUid ? _cached : const AppSettings();
  }

  @override
  Stream<AppSettings> watch() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const AppSettings());
    return _doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      _cached = data == null ? const AppSettings() : AppSettings.fromMap(data);
      _cachedUid = uid;
      return _cached;
    });
  }

  @override
  Future<void> save(AppSettings settings) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppFailure('Please log in again.');
    try {
      await _doc(
        uid,
      ).set({...settings.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
      _cached = settings;
      _cachedUid = uid;
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }
}
