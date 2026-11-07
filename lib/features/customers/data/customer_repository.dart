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
  Future<String> add({required String name, required String phone, required String address});

  Future<void> update(String id, {required String name, required String phone, required String address});
}

/// Data lives under `users/{uid}/customers`; Firestore rules allow only that user.
class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _customers {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please log in again.');
    return _firestore.collection('users').doc(user.uid).collection('customers');
  }

  static Customer _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Customer(
        id: doc.id,
        name: doc['displayName'] as String,
        phone: doc['phone'] as String,
        address: doc['address'] as String,
      );

  static Map<String, Object> _fields(String name, String phone, String address) {
    final cleanName = collapseSpaces(name);
    return {
      'displayName': cleanName,
      'displayNameLower': cleanName.toLowerCase(),
      'phone': phone.trim(),
      'phoneNormalized': normalizePhone(phone),
      'address': address.trim(),
    };
  }

  @override
  Stream<List<Customer>> watchAll() =>
      _customers
          .orderBy('displayNameLower')
          .snapshots()
          .map((snapshot) => [for (final doc in snapshot.docs) _fromDoc(doc)])
          .withFirestoreFailures();

  @override
  Future<Customer?> findByPhone(String phone, {String? excludeId}) => _run(() async {
        final matches = await _customers.where('phoneNormalized', isEqualTo: normalizePhone(phone)).limit(2).get();
        for (final doc in matches.docs) {
          if (doc.id != excludeId) return _fromDoc(doc);
        }
        return null;
      });

  @override
  Future<String> add({required String name, required String phone, required String address}) => _run(() {
        final ref = _customers.doc();
        return _firestore.runTransaction((tx) async {
          tx.set(ref, {
            ..._fields(name, phone, address),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return ref.id;
        });
      });

  @override
  Future<void> update(String id, {required String name, required String phone, required String address}) => _run(
        () => _firestore.runTransaction((tx) async {
          tx.update(_customers.doc(id), {..._fields(name, phone, address), 'updatedAt': FieldValue.serverTimestamp()});
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
