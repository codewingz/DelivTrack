import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/firestore_failure.dart';
import '../../../core/ids/order_number.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../utils/text.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_input.dart';
import '../../../utils/postal_reference.dart';

abstract class ParcelRepository {
  /// All of the signed-in user's parcels, newest first.
  Stream<List<Parcel>> watchAll();

  /// One parcel, or null if it does not exist.
  Stream<Parcel?> watch(String id);

  /// Creates the parcel with the next order number. Returns the new parcel's id.
  /// Throws [AppFailure] (invalid input, reference already used, no connection...).
  Future<String> create(ParcelInput input);
}

/// Data lives under `users/{uid}/parcels`; Firestore rules allow only that user.
///
/// * Order numbers come from `users/{uid}/counters/orders`, read and bumped in the same
///   transaction that writes the parcel, so two saves can never share a number.
/// * A postal reference may be used once per service: `users/{uid}/postal_refs/{key}` guard
///   documents are written in the same transaction.
class FirestoreParcelRepository implements ParcelRepository {
  FirestoreParcelRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, this.clock = const Clock()})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Clock clock;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please log in again.');
    return _firestore.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> get _parcels => _userDoc.collection('parcels');
  DocumentReference<Map<String, dynamic>> get _counter => _userDoc.collection('counters').doc('orders');

  /// Guard document for a service + reference ("Other" services are told apart by their name).
  DocumentReference<Map<String, dynamic>> _guard(PostalService service, String? otherName, String normalizedReference) {
    final serviceKey = service == PostalService.other ? 'Other-${collapseSpaces(otherName ?? '').toLowerCase()}' : service.value;
    return _userDoc.collection('postal_refs').doc('${Uri.encodeComponent(serviceKey)}__${Uri.encodeComponent(normalizedReference)}');
  }

  @override
  Stream<List<Parcel>> watchAll() => _parcels
      .orderBy('orderSequence', descending: true)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) Parcel.fromMap(doc.id, doc.data())])
      .withFirestoreFailures();

  @override
  Stream<Parcel?> watch(String id) => _parcels
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Parcel.fromMap(doc.id, doc.data()!) : null)
      .withFirestoreFailures();

  @override
  Future<String> create(ParcelInput input) async {
    final problems = input.problems(today: pakistanDate(clock.nowUtc()));
    if (problems.isNotEmpty) throw AppFailure(problems.first);

    try {
      final parcelRef = _parcels.doc();
      final normalizedReference = normalizePostalReference(input.postalReference);
      final guard = normalizedReference.isEmpty
          ? null
          : _guard(input.service, input.otherServiceName, normalizedReference);

      // Two saves at the same moment both read the same counter. The mobile SDK commits with a
      // "counter unchanged" precondition, but Firestore checks the rules first, so the loser is
      // answered "permission-denied" (not the retryable "aborted"). Verified against the real
      // backend (5 parallel saves: one wins per round, all succeed within 5 attempts). So a
      // denied attempt is retried a few times with a fresh counter read; a genuine denial fails
      // the same way every time and is reported after the last attempt.
      for (var attempt = 1;; attempt++) {
        try {
          return await _firestore.runTransaction((tx) async {
            final counter = await tx.get(_counter);
            final sequence = (counter.exists ? counter['lastSequence'] as int : 0) + 1;
            final orderNumber = formatOrderNumber(sequence);

            if (guard != null) {
              final existing = await tx.get(guard);
              if (existing.exists) {
                throw AppFailure('This postal reference is already used on ${existing['orderNumber']}.');
              }
            }

            tx.set(_counter, {'lastSequence': sequence});
            tx.set(parcelRef, _newParcelFields(input, orderNumber, sequence, normalizedReference));
            if (guard != null) tx.set(guard, {'parcelId': parcelRef.id, 'orderNumber': orderNumber});
            return parcelRef.id;
          });
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied' || attempt >= _maxCreateAttempts) throw firestoreFailure(e);
          await Future<void>.delayed(Duration(milliseconds: 25 * attempt + _jitter.nextInt(75)));
        }
      }
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  static const _maxCreateAttempts = 5;
  static final _jitter = Random();

  Map<String, Object> _newParcelFields(ParcelInput input, String orderNumber, int sequence, String normalizedReference) {
    final isFree = input.method == CollectionMethod.giftFree;
    final expected = input.expectedPaisa;
    return {
      'orderNumber': orderNumber,
      'orderSequence': sequence,
      'customerId': input.customer.id,
      'customerSnapshot': {
        'name': input.customer.name,
        'phone': input.customer.phone,
        'address': input.customer.address,
      },
      'items': [for (final item in input.items) item.toMap()],
      'collectionMethod': input.method.value,
      'postalServiceType': input.service.value,
      'otherPostalServiceName': ?(input.service == PostalService.other ? collapseSpaces(input.otherServiceName ?? '') : null),
      'postalReference': input.postalReference.trim(),
      'postalReferenceNormalized': normalizedReference,
      'deliveryChargePaisa': ?input.deliveryChargePaisa,
      'actualPackedWeightGrams': ?input.packedWeightGrams,
      'estimatedPaymentDateLocal': ?input.estimatedPaymentDate,
      'productAmountExpectedPaisa': expected,
      'receivedPaisa': 0,
      'outstandingPaisa': expected,
      'paymentStatus': (isFree ? PaymentStatus.notRequired : PaymentStatus.pending).value,
      'parcelStatus': input.status.value,
      'sendingDateLocal': pakistanDate(clock.nowUtc()),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
