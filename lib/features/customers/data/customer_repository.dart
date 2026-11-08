import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/firestore_failure.dart';
import '../../../utils/phone.dart';
import '../../../utils/text.dart';
import '../domain/customer.dart';

abstract class CustomerRepository {
  /// All of the signed-in user's customers, sorted by name.
  Stream<List<Customer>> watchAll();

  /// Another customer (not [excludeId]) with the same normalized phone, or null.
  Future<Customer?> findByPhone(String phone, {String? excludeId});

  /// Returns the new customer's id. Throws [AppFailure] (e.g. no connection).
  /// [phone2] and [businessDetails] are optional; empty means none.
  Future<String> add({
    required String name,
    required String phone,
    required String address,
    String phone2 = '',
    String businessDetails = '',
  });

  Future<void> update(
    String id, {
    required String name,
    required String phone,
    required String address,
    String phone2 = '',
    String businessDetails = '',
  });
}

/// Data lives under `users/{uid}/customers`; Firestore rules allow only that user.
class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _customers {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please log in again.');
    return _firestore.collection('users').doc(user.uid).collection('customers');
  }

  static Customer _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Customer(
        id: doc.id,
        name: doc['displayName'] as String,
        phone: doc['phone'] as String,
        address: doc['address'] as String,
        phone2: doc.data()['phone2'] as String? ?? '',
        businessDetails: doc.data()['businessDetails'] as String? ?? '',
      );

  /// The optional fields are left out when empty. On update, [clearEmpty] removes them from the
  /// document instead, so a cleared field really goes away.
  static Map<String, Object> _fields(
    String name,
    String phone,
    String address,
    String phone2,
    String businessDetails, {
    required bool clearEmpty,
  }) {
    final cleanName = collapseSpaces(name);
    final optional = {
      'phone2': phone2.trim(),
      // Line breaks become spaces: the rules only accept single-line text.
      'businessDetails': collapseSpaces(businessDetails),
    };
    return {
      'displayName': cleanName,
      'displayNameLower': cleanName.toLowerCase(),
      'phone': phone.trim(),
      'phoneNormalized': normalizePhone(phone),
      'address': address.trim(),
      for (final entry in optional.entries)
        if (entry.value.isNotEmpty)
          entry.key: entry.value
        else if (clearEmpty)
          entry.key: FieldValue.delete(),
    };
  }

  @override
  Stream<List<Customer>> watchAll() => _customers
      .orderBy('displayNameLower')
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) _fromDoc(doc)])
      .withFirestoreFailures();

  @override
  Future<Customer?> findByPhone(String phone, {String? excludeId}) =>
      _run(() async {
        final matches = await _customers
            .where('phoneNormalized', isEqualTo: normalizePhone(phone))
            .limit(2)
            .get();
        for (final doc in matches.docs) {
          if (doc.id != excludeId) return _fromDoc(doc);
        }
        return null;
      });

  @override
  Future<String> add({
    required String name,
    required String phone,
    required String address,
    String phone2 = '',
    String businessDetails = '',
  }) => _run(() {
    final ref = _customers.doc();
    return _firestore.runTransaction((tx) async {
      tx.set(ref, {
        ..._fields(
          name,
          phone,
          address,
          phone2,
          businessDetails,
          clearEmpty: false,
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    });
  });

  @override
  Future<void> update(
    String id, {
    required String name,
    required String phone,
    required String address,
    String phone2 = '',
    String businessDetails = '',
  }) => _run(
    () => _firestore.runTransaction((tx) async {
      tx.update(_customers.doc(id), {
        ..._fields(
          name,
          phone,
          address,
          phone2,
          businessDetails,
          clearEmpty: true,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }
}
