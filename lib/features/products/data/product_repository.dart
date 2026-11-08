import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/firestore_failure.dart';
import '../domain/product.dart';

abstract class ProductRepository {
  /// All of the signed-in user's products (active and archived), sorted by name.
  Stream<List<Product>> watchAll();

  /// Throws [AppFailure] (e.g. duplicate name, no connection).
  Future<void> add({required String name, required SaleUnit saleUnit});

  Future<void> update(
    String id, {
    required String name,
    required SaleUnit saleUnit,
  });

  /// Archive (false) or restore (true). Products are never deleted.
  Future<void> setActive(String id, bool isActive);
}

const duplicateProductMessage = 'A product with this name already exists.';

/// Data lives under `users/{uid}/products`; Firestore rules allow only that user.
/// Names are unique per user (case-insensitive) through `users/{uid}/product_names/{key}`
/// guard documents written in the same transaction as the product.
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please log in again.');
    return _firestore.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> get _products =>
      _userDoc.collection('products');
  DocumentReference<Map<String, dynamic>> _guard(String name) =>
      _userDoc.collection('product_names').doc(productNameKey(name));

  @override
  Stream<List<Product>> watchAll() => _products
      .orderBy('nameLower')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            Product(
              id: doc.id,
              name: doc['name'] as String,
              saleUnit: SaleUnit.fromValue(doc['saleUnit'] as String),
              isActive: doc['isActive'] as bool,
            ),
        ],
      )
      .withFirestoreFailures();

  @override
  Future<void> add({required String name, required SaleUnit saleUnit}) =>
      _run(() {
        final cleaned = normalizeProductName(name);
        final ref = _products.doc();
        final guard = _guard(cleaned);
        return _firestore.runTransaction((tx) async {
          if ((await tx.get(guard)).exists) {
            throw const AppFailure(duplicateProductMessage);
          }
          tx.set(ref, {
            'name': cleaned,
            'nameLower': cleaned.toLowerCase(),
            'saleUnit': saleUnit.value,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(guard, {'productId': ref.id});
        });
      });

  @override
  Future<void> update(
    String id, {
    required String name,
    required SaleUnit saleUnit,
  }) => _run(() {
    final cleaned = normalizeProductName(name);
    final ref = _products.doc(id);
    return _firestore.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (!current.exists) {
        throw const AppFailure('This product no longer exists.');
      }
      final oldGuard = _guard(current['name'] as String);
      final newGuard = _guard(cleaned);
      if (newGuard.path != oldGuard.path) {
        if ((await tx.get(newGuard)).exists) {
          throw const AppFailure(duplicateProductMessage);
        }
        tx.delete(oldGuard);
        tx.set(newGuard, {'productId': id});
      }
      tx.update(ref, {
        'name': cleaned,
        'nameLower': cleaned.toLowerCase(),
        'saleUnit': saleUnit.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> setActive(String id, bool isActive) => _run(
    () => _products.doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }
}
