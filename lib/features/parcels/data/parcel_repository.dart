import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/data/changed_keys.dart';
import '../../../core/errors/firestore_failure.dart';
import '../../../core/ids/order_number.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../utils/text.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_input.dart';
import '../domain/payment.dart';
import '../domain/payment_rules.dart';
import '../../../utils/postal_reference.dart';

abstract class ParcelRepository {
  /// All of the signed-in user's parcels, newest first.
  Stream<List<Parcel>> watchAll();

  /// One parcel, or null if it does not exist.
  Stream<Parcel?> watch(String id);

  /// Creates the parcel with the next order number. Returns the new parcel's id.
  /// Throws [AppFailure] (invalid input, reference already used, no connection...).
  Future<String> create(ParcelInput input);

  /// Edits an existing parcel. The order number, sending date and creation time never change;
  /// payments already received are kept. Writes an audit-log entry with the changed fields.
  /// Throws [AppFailure] (not found, reference already used, no connection...).
  Future<void> update(String id, ParcelInput input);

  /// A parcel's payments, newest first.
  Stream<List<Payment>> watchPayments(String parcelId);

  /// Records a payment and moves the parcel's received / outstanding / payment status in one
  /// transaction. Throws [AppFailure] (amount not above 0 or above the outstanding balance, Gift / Free
  /// or returned parcel, note too long, no connection...).
  Future<void> recordPayment(String parcelId, {required int amountPaisa, required PaymentType type, String? note});
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

      return await _retryWhenDenied(() => _firestore.runTransaction((tx) async {
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
      }));
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  static const _maxAttempts = 5;
  static final _jitter = Random();

  /// Two writes at the same moment both read the same document. The mobile SDK commits with an
  /// "unchanged since read" precondition, but Firestore checks the rules first, so the loser is
  /// answered "permission-denied" (not the retryable "aborted"). Verified against the real backend
  /// (5 parallel saves: one wins per round, all succeed within 5 attempts). So a denied attempt is
  /// retried a few times with a fresh read; a genuine denial fails the same way every time and is
  /// reported after the last attempt.
  Future<T> _retryWhenDenied<T>(Future<T> Function() attempt) async {
    for (var tries = 1;; tries++) {
      try {
        return await attempt();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || tries >= _maxAttempts) throw firestoreFailure(e);
        await Future<void>.delayed(Duration(milliseconds: 25 * tries + _jitter.nextInt(75)));
      }
    }
  }

  @override
  Future<void> update(String id, ParcelInput input) async {
    final problems = input.problems();
    if (problems.isNotEmpty) throw AppFailure(problems.first);

    try {
      final parcelRef = _parcels.doc(id);
      final auditRef = _userDoc.collection('audit_logs').doc();
      final normalizedReference = normalizePostalReference(input.postalReference);
      final newGuard = normalizedReference.isEmpty ? null : _guard(input.service, input.otherServiceName, normalizedReference);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(parcelRef);
        if (!snapshot.exists) throw const AppFailure('This parcel no longer exists.');
        final before = snapshot.data()!;

        if (before['parcelStatus'] == ParcelStatus.returned.value) {
          throw const AppFailure("A returned parcel can't be edited.");
        }
        final received = before['receivedPaisa'] as int;
        final wasFree = before['collectionMethod'] == CollectionMethod.giftFree.value;
        final isFree = input.method == CollectionMethod.giftFree;
        if (received > 0 && wasFree != isFree) {
          throw const AppFailure("The parcel type can't change between Gift / Free and a paid type after a payment was received.");
        }

        final oldReference = before['postalReferenceNormalized'] as String;
        final oldGuard = oldReference.isEmpty
            ? null
            : _guard(PostalService.fromValue(before['postalServiceType'] as String), before['otherPostalServiceName'] as String?, oldReference);

        if (newGuard != null && newGuard.path != oldGuard?.path) {
          final existing = await tx.get(newGuard);
          if (existing.exists) throw AppFailure('This postal reference is already used on ${existing['orderNumber']}.');
        }

        final expected = input.expectedPaisa;
        final updated = _editableFields(input, normalizedReference, expected, received, isFree);
        final changed = changedKeys(before, {...before, ...updated}..removeWhere((key, value) => value == null));
        if (changed.isEmpty) return;

        if (oldGuard != null && oldGuard.path != newGuard?.path) tx.delete(oldGuard);
        if (newGuard != null && newGuard.path != oldGuard?.path) {
          tx.set(newGuard, {'parcelId': id, 'orderNumber': before['orderNumber']});
        }
        tx.update(parcelRef, {
          for (final entry in updated.entries) entry.key: entry.value ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(auditRef, {
          'entityType': 'parcel',
          'entityId': id,
          'action': 'update',
          'orderNumber': before['orderNumber'],
          'changedFields': changed,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  @override
  Stream<List<Payment>> watchPayments(String parcelId) => _parcels
      .doc(parcelId)
      .collection('payments')
      .orderBy('receivedAt', descending: true)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              Payment(
                id: doc.id,
                amountPaisa: doc['amountPaisa'] as int,
                type: PaymentType.fromValue(doc['paymentType'] as String),
                note: doc.data()['note'] as String?,
                receivedAt: (doc['receivedAt'] as Timestamp).toDate(),
              ),
          ])
      .withFirestoreFailures();

  @override
  Future<void> recordPayment(String parcelId, {required int amountPaisa, required PaymentType type, String? note}) async {
    final cleanNote = collapseSpaces(note ?? '');
    final problem = paymentProblem(amountPaisa: amountPaisa, note: cleanNote);
    if (problem != null) throw AppFailure(problem);

    final parcelRef = _parcels.doc(parcelId);
    final paymentRef = parcelRef.collection('payments').doc();
    try {
      await _retryWhenDenied(() => _firestore.runTransaction((tx) async {
            final snapshot = await tx.get(parcelRef);
            if (!snapshot.exists) throw const AppFailure('This parcel no longer exists.');
            final parcel = snapshot.data()!;
            if (parcel['parcelStatus'] == ParcelStatus.returned.value) throw const AppFailure("A returned parcel can't take payments.");
            final isFree = parcel['collectionMethod'] == CollectionMethod.giftFree.value;
            if (isFree) throw const AppFailure('A Gift / Free parcel has no payment to receive.');

            final outstanding = parcel['outstandingPaisa'] as int;
            if (amountPaisa > outstanding) throw AppFailure('Cannot exceed outstanding ${formatRupees(outstanding)}.');

            final expected = parcel['productAmountExpectedPaisa'] as int;
            final received = (parcel['receivedPaisa'] as int) + amountPaisa;
            tx.update(parcelRef, {
              'receivedPaisa': received,
              'outstandingPaisa': outstandingFor(expectedPaisa: expected, receivedPaisa: received),
              'paymentStatus': paymentStatusFor(isFree: isFree, expectedPaisa: expected, receivedPaisa: received).value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            tx.set(paymentRef, {
              'amountPaisa': amountPaisa,
              'paymentType': type.value,
              if (cleanNote.isNotEmpty) 'note': cleanNote,
              'receivedAt': FieldValue.serverTimestamp(),
              'recordedAt': FieldValue.serverTimestamp(),
            });
          }));
    } on FirebaseException catch (e) {
      throw firestoreFailure(e);
    }
  }

  /// The fields an edit may change. A null value means "remove this optional field".
  Map<String, Object?> _editableFields(ParcelInput input, String normalizedReference, int expected, int received, bool isFree) => {
        'customerId': input.customer.id,
        'customerSnapshot': {
          'name': input.customer.name,
          'phone': input.customer.phone,
          'address': input.customer.address,
        },
        'items': [for (final item in input.items) item.toMap()],
        'collectionMethod': input.method.value,
        'postalServiceType': input.service.value,
        'otherPostalServiceName': input.service == PostalService.other ? collapseSpaces(input.otherServiceName ?? '') : null,
        'postalReference': input.postalReference.trim(),
        'postalReferenceNormalized': normalizedReference,
        'deliveryChargePaisa': input.deliveryChargePaisa,
        'actualPackedWeightGrams': input.packedWeightGrams,
        'estimatedPaymentDateLocal': input.estimatedPaymentDate,
        'productAmountExpectedPaisa': expected,
        'outstandingPaisa': outstandingFor(expectedPaisa: expected, receivedPaisa: received),
        'paymentStatus': paymentStatusFor(isFree: isFree, expectedPaisa: expected, receivedPaisa: received).value,
        'parcelStatus': input.status.value,
      };

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
