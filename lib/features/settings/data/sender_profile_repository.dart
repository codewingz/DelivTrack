import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/firestore_failure.dart';
import '../domain/sender_profile.dart';

abstract class SenderProfileRepository {
  Future<SenderProfile?> getProfile();
  Stream<SenderProfile?> watchProfile();
  Future<void> saveProfile(SenderProfile profile);
}

/// Fallback when running without Firebase (e.g. widget tests).
class NoSenderProfileRepository implements SenderProfileRepository {
  const NoSenderProfileRepository();

  @override
  Future<SenderProfile?> getProfile() async => null;

  @override
  Stream<SenderProfile?> watchProfile() => Stream.value(null);

  @override
  Future<void> saveProfile(SenderProfile profile) async {}
}

class FirestoreSenderProfileRepository implements SenderProfileRepository {
  FirestoreSenderProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('sender_profile');

  @override
  Future<SenderProfile?> getProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists || snap.data() == null) return null;
      return SenderProfile.fromMap(snap.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Device is offline / DNS unresolvable and document not in local cache yet.
        return null;
      }
      throw firestoreFailure(e);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<SenderProfile?> watchProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SenderProfile.fromMap(snap.data()!);
    });
  }

  @override
  Future<void> saveProfile(SenderProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppFailure('Sign in required.');
    try {
      // Every field of the profile (toMap), so a new one is never left out.
      await _doc(uid).set({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppFailure(e.message ?? 'Failed to save sender details.');
    }
  }
}
